#!/usr/bin/env bash
set -euo pipefail
ROOT=~/keystone_worldtrain
mkdir -p "$ROOT"/{corpus,models,data,logs}
cd "$ROOT"

python3 -m venv .venv >/dev/null 2>&1 || true
source .venv/bin/activate
python -m pip install --upgrade pip >/dev/null
pip install datasets==2.21.0 transformers==4.44.2 peft==0.12.0 accelerate==0.34.2 \
             sentence-transformers==3.0.1 faiss-cpu==1.8.0 arxiv==2.1.3 pyyaml==6.0.2 \
             fastapi==0.114.0 uvicorn==0.30.6 tiktoken==0.7.0 >/dev/null

cat > .env <<'EOT'
# knobs
MAX_DOCS_PER_SOURCE=20000
BASE_MODEL_ID=TinyLlama/TinyLlama-1.1B-Chat-v1.0
BASE_MODEL_ID_2=Qwen/Qwen2-1.5B-Instruct
EMBED_MODEL=sentence-transformers/all-MiniLM-L6-v2
EOT

cat > sources.yml <<'YML'
# enabled by default: permissive corpora. Toggle others manually.
wikipedia:
  enabled: true
  langs: [en]
  max: ${MAX_DOCS_PER_SOURCE}
arxiv:
  enabled: true
  query: (cat:cs* OR cat:stat.ML)
  max: 5000
commoncrawl:
  enabled: false     # off by default
pubmed:
  enabled: false     # off by default
YML

cat > crawler.py <<'PY'
import os, json, yaml, re, time
from pathlib import Path
from datasets import load_dataset
import arxiv

ROOT=Path(__file__).parent
CORP=ROOT/"corpus"; CORP.mkdir(exist_ok=True)
cfg=yaml.safe_load((ROOT/"sources.yml").read_text())
max_docs=int(os.getenv("MAX_DOCS_PER_SOURCE", "20000"))

def clean(txt:str)->str:
    txt=re.sub(r'\s+', ' ', txt).strip()
    return txt

def add_stream(name, it):
    out=(CORP/f"{name}.jsonl").open("w", encoding="utf-8")
    n=0
    for rec in it:
        if not rec: continue
        if "text" not in rec or not rec["text"]: continue
        rec["text"]=clean(rec["text"])
        if len(rec["text"])<200: continue
        out.write(json.dumps(rec, ensure_ascii=False)+"\n"); n+=1
    out.close(); print(f"{name}: {n} docs")

if cfg.get("wikipedia",{}).get("enabled"):
    langs=cfg["wikipedia"].get("langs",["en"])
    limit=min(int(cfg["wikipedia"].get("max", max_docs)), max_docs)
    for lang in langs:
        ds=load_dataset("wikipedia", f"{lang}", split="train", streaming=True)
        def gen():
            i=0
            for x in ds:
                yield {"id":x["id"], "title":x["title"], "text":x["text"], "src":"wikipedia"}
                i+=1
                if i>=limit: break
        add_stream(f"wikipedia_{lang}", gen())

if cfg.get("arxiv",{}).get("enabled"):
    q=cfg["arxiv"].get("query","cat:cs*"); lim=int(cfg["arxiv"].get("max",5000))
    cl=arxiv.Client(page_size=100, delay_seconds=1, num_retries=2)
    results=cl.results(arxiv.Search(query=q, max_results=lim, sort_by=arxiv.SortCriterion.SubmittedDate))
    def gen():
        i=0
        for r in results:
            txt=f"{r.title}\n\n{r.summary}"
            yield {"id":r.get_short_id(), "title":r.title, "text":txt, "src":"arxiv"}
            i+=1
            if i>=lim: break
    add_stream("arxiv", gen())
PY

cat > dedupe_merge.py <<'PY'
import json, hashlib
from pathlib import Path
ROOT=Path(__file__).parent
out=ROOT/"data"/"corpus.jsonl"; out.parent.mkdir(exist_ok=True)
seen=set(); n=0; w=out.open("w",encoding="utf-8")
for p in sorted((ROOT/"corpus").glob("*.jsonl")):
    for line in p.open(encoding="utf-8"):
        try: rec=json.loads(line)
        except: continue
        h=hashlib.sha1((rec.get("title","")+rec.get("text",""))[:1000].encode()).hexdigest()
        if h in seen: continue
        seen.add(h); w.write(json.dumps(rec,ensure_ascii=False)+"\n"); n+=1
w.close(); print("merged", n)
PY

cat > embed_index.py <<'PY'
import json, pickle, os
from pathlib import Path
from sentence_transformers import SentenceTransformer
import faiss
ROOT=Path(__file__).parent
data=list(map(json.loads, (ROOT/"data"/"corpus.jsonl").read_text(encoding="utf-8").splitlines()))
texts=[d["text"][:2000] for d in data]
model = SentenceTransformer(os.getenv("EMBED_MODEL","sentence-transformers/all-MiniLM-L6-v2"))
emb = model.encode(texts, normalize_embeddings=True, show_progress_bar=True)
index = faiss.IndexFlatIP(emb.shape[1]); index.add(emb.astype("float32"))
faiss.write_index(index, str(ROOT/"data"/"index.faiss"))
pickle.dump(data, open(ROOT/"data"/"docs.pkl","wb"))
print("indexed", len(data))
PY

cat > make_sft.py <<'PY'
# turns corpus into short instruction->output pairs to avoid verbatim long copies
import json, random
from pathlib import Path
src=Path(__file__).parent/"data"/"corpus.jsonl"
dst=Path(__file__).parent/"data"/"sft.jsonl"
random.seed(7)
def chunk(s, n=1200): return s if len(s)<=n else s[:n]
with src.open(encoding="utf-8") as f, dst.open("w",encoding="utf-8") as w:
    for i,line in enumerate(f):
        rec=json.loads(line); t=rec.get("text","")
        if not t: continue
        tasks=[
            ("Summarize the passage in 3 bullets:", "• "),
            ("Extract 3 key terms from the passage:", "Keys: "),
            ("Give one-line takeaway:", "")
        ]
        instr, prefix = random.choice(tasks)
        w.write(json.dumps({"instruction":instr, "input":"","output":prefix+chunk(t, 600)})+"\n")
print("sft written")
PY

cat > train_sft.py <<'PY'
import os, json
from datasets import load_dataset
from transformers import AutoModelForCausalLM, AutoTokenizer
from transformers import TrainingArguments
from peft import LoraConfig, get_peft_model
from transformers import DataCollatorForLanguageModeling, Trainer
import torch

base=os.getenv("BASE_MODEL_ID","TinyLlama/TinyLlama-1.1B-Chat-v1.0")
tok=AutoTokenizer.from_pretrained(base, use_fast=True)
tok.pad_token = tok.eos_token
ds=load_dataset("json", data_files="data/sft.jsonl")

def fmt(e):
    return { "input_ids": tok(f"### Instruction:\n{e['instruction']}\n\n### Response:\n{e['output']}", truncation=True, max_length=1024, return_tensors=None)["input_ids"] }

ds=ds.map(fmt, remove_columns=ds["train"].column_names)
model=AutoModelForCausalLM.from_pretrained(base, torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32)
lora=LoraConfig(r=8, lora_alpha=16, lora_dropout=0.05, target_modules=["q_proj","v_proj","k_proj","o_proj"])
model=get_peft_model(model, lora)

args=TrainingArguments(
    output_dir="models/ashleyana_lora",
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    num_train_epochs=1,
    learning_rate=2e-4,
    bf16=torch.cuda.is_available(),
    logging_steps=50,
    save_steps=200,
    save_total_limit=2
)
collator=DataCollatorForLanguageModeling(tok, mlm=False)
trainer=Trainer(model=model, args=args, train_dataset=ds["train"], data_collator=collator)
trainer.train()
model.save_pretrained("models/ashleyana_lora"); tok.save_pretrained("models/ashleyana_lora")
print("ashleyana trained")
PY

cat > train_tools.py <<'PY'
# shadowx: smaller tool-use oriented pass using same SFT for brevity
import os, torch
from datasets import load_dataset
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, DataCollatorForLanguageModeling, Trainer
from peft import LoraConfig, get_peft_model

base=os.getenv("BASE_MODEL_ID_2","Qwen/Qwen2-1.5B-Instruct")
tok=AutoTokenizer.from_pretrained(base, use_fast=True)
tok.pad_token = tok.eos_token
ds=load_dataset("json", data_files="data/sft.jsonl")
def fmt(e): return { "input_ids": tok(f"[INST]{e['instruction']}[/INST]\n{e['output']}", truncation=True, max_length=1024)["input_ids"] }
ds=ds.map(fmt, remove_columns=ds["train"].column_names)
model=AutoModelForCausalLM.from_pretrained(base, torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32)
lora=LoraConfig(r=8, lora_alpha=16, lora_dropout=0.05, target_modules=["q_proj","v_proj","k_proj","o_proj"])
model=get_peft_model(model, lora)
args=TrainingArguments(output_dir="models/shadowx_lora", per_device_train_batch_size=2, gradient_accumulation_steps=8, num_train_epochs=1, learning_rate=2e-4, bf16=torch.cuda.is_available(), logging_steps=50, save_steps=200, save_total_limit=2)
collator=DataCollatorForLanguageModeling(tok, mlm=False)
Trainer(model=model, args=args, train_dataset=ds["train"], data_collator=collator).train()
model.save_pretrained("models/shadowx_lora"); tok.save_pretrained("models/shadowx_lora")
print("shadowx trained")
PY

cat > serve_retriever.py <<'PY'
import os, pickle, faiss
from pathlib import Path
from fastapi import FastAPI, Query
from sentence_transformers import SentenceTransformer
app=FastAPI()
ROOT=Path(__file__).parent
index=faiss.read_index(str(ROOT/"data"/"index.faiss"))
docs=pickle.load(open(ROOT/"data"/"docs.pkl","rb"))
emb=SentenceTransformer(os.getenv("EMBED_MODEL","sentence-transformers/all-MiniLM-L6-v2"))
@app.get("/search")
def search(q: str=Query(...), k: int=5):
    v=emb.encode([q], normalize_embeddings=True).astype("float32")
    D,I=index.search(v, k)
    res=[{k:docs[i][k] for k in ("title","text","src")} for i in I[0]]
    return {"hits":res}
PY

cat > run_all.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source .venv/bin/activate
python crawler.py
python dedupe_merge.py
python embed_index.py
python make_sft.py
python train_sft.py
python train_tools.py
uvicorn serve_retriever:app --host 127.0.0.1 --port 8077 --reload &
echo "retriever at http://127.0.0.1:8077/search?q=AI"
SH
chmod +x run_all.sh
echo "OK"
