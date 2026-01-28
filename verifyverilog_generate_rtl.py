from langchain_openai import ChatOpenAI
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, MessagesState, StateGraph, END
from os import getenv
from dotenv import load_dotenv
from typing_extensions import Annotated, TypedDict, Literal
import os
from utils.simulation_helpers import *
from utils.file_helpers import *
from system_prompt import *
#from run_config import run_config
import asyncio
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent
from langgraph.prebuilt import ToolNode
from langgraph.types import Command
import aiofiles
import pandas as pd
import json
import re
import ast
from tqdm import tqdm
from tqdm.asyncio import tqdm as async_tqdm
from datetime import datetime
from langsmith import tracing_context
import time
CURRENT_DIR = os.getcwd()
load_dotenv()
#Configuration
MAX_CONCURRENT_LLM_CALLS = 15  # Single semaphore is cleaner
CHECKPOINT_BATCH_SIZE = 10    # Batch checkpoint writes
K = 1
# Shared state
METRICS_LOG = []
COMPLETED_PROBLEMS = set()
METRICS_LOCK = asyncio.Lock()
COMPLETED_LOCK = asyncio.Lock()
_pending_completions = []  # Buffer for batch checkpoint write

model = ChatOpenAI(
        openai_api_key=getenv("OPENROUTER_API_KEY"),
        openai_api_base=getenv("OPENROUTER_BASE_URL"),
        model_name="tngtech/deepseek-r1t2-chimera:free",
        #model_name="anthropic/claude-sonnet-4.5",
        #model_name="x-ai/grok-code-fast-1",
        #model_name="minimax/minimax-m2:free",
        #model_name="openrouter/polaris-alpha",
        #model_name="xiaomi/mimo-v2-flash:free",
        #model_name="mistralai/devstral-2512:free",
        #model_name="allenai/olmo-3.1-32b-think:free",
        #model_name="mistralai/devstral-2512:free",
        #model_name="qwen/qwen3-coder:free",
        extra_body={
            "provider": {
                "order": ["Chutes"],
                "sort": "throughput",
                "allow_fallbacks": True
            },
        }
    )

parser_model = ChatOpenAI(
    openai_api_key=getenv("OPENROUTER_API_KEY"),
    openai_api_base=getenv("OPENROUTER_BASE_URL"),
    model_name="tngtech/tng-r1t-chimera:free",
    extra_body={
        "models": ["mistralai/mistral-small-3.1-24b-instruct:free", "arcee-ai/trinity-mini:free"],
        "allow_fallbacks": True
    }
)

with open('prompt_hdl.txt', 'r', encoding='utf-8') as f:
    SYSTEM_PROMPT = f.read()
    
class code_output(TypedDict):
    """Schema for System Verilog Code"""
    code: str = Annotated[str, ..., "verilog code block only"] 
    
structured_parser_model = parser_model.with_structured_output(code_output) 


  
async def call_model_with_retry(model, messages, max_retries=5, base_delay=2):
    for attempt in range(max_retries):
        try:
            with tracing_context(enabled=False):
                response = await model.ainvoke(messages)
            #print(response)
            return response
        except Exception as e:
            wait_time = base_delay * (2 ** attempt)
            print(f"Rate limit hit. Retrying in {wait_time} seconds...{e}")
            await asyncio.sleep(wait_time)
    raise Exception(f"Max retries exceeded due to rate limiting.")

async def run_eval(user_prompt):

    message = SYSTEM_PROMPT + user_prompt
    try:
        response = await call_model_with_retry(model, message)
    except Exception as e:
        print(f"Failed to get model response: {e}")
        return None
    return response

def extract_code_from_llm_output(content):
    """
    Extracts the SystemVerilog code string from LLM output containing a markdown JSON code block.
    Handles both JSON and Python dict style, and preserves SystemVerilog literals.
    """
    # Step 1: Extract the JSON code block from markdown
    match = re.search(r"```json\s*([\s\S]+?)\s*```", content)
    if not match:
        raise ValueError("No JSON code block found in the content.")
    json_block = match.group(1).strip()
    
    # Step 2: Try JSON parsing first
    try:
        data = json.loads(json_block)
    except json.JSONDecodeError:
        # Fallback: Try Python dict parsing
        try:
            data = ast.literal_eval(json_block)
        except Exception as e:
            #print(json_block)
            raise ValueError(f"Failed to parse code block as JSON or Python dict: {e}")
    
    # Step 3: Unescape newlines for the code string
    code = data['code']#.replace('\\n', '\n')
    return code

async def run_and_log(task_id, source, working_dir, user_prompt, semaphore, i):
    """
    Optimized: Semaphore only around LLM call, not file I/O
    """
    PARSER_PROMPT = "Extract the verilog code..."
    
    # LLM call with semaphore
    async with semaphore:
        response = await run_eval(user_prompt)
    
    if response is None:
        print(f"Failed to get response for {task_id}, iteration {i}")
        return False
    
    # File I/O outside semaphore (doesn't need throttling)
    verilog_filename = os.path.join(working_dir, f"{task_id}_gen_{i}.sv")
    
    try:
        code = extract_code_from_llm_output(response.content)
    except:
        try:
            async with semaphore:  # Parser also uses API
                parse_message = PARSER_PROMPT + "\n" + response.content
                code_output_result = await call_model_with_retry(structured_parser_model, parse_message)
            code = code_output_result["code"]
        except Exception as e:
            print(f"Failed to parse code for {task_id}, iteration {i}: {e}")
            code = f"// Failed to parse code\n{response.content}"
    
    # Write file (no semaphore needed)
    async with aiofiles.open(verilog_filename, "w", encoding="utf-8") as f:
        await f.write(code)
    
    # Log metrics
    async with METRICS_LOCK:
        METRICS_LOG.append({
            "task_id": task_id,
            "source": source,
            "iteration": i,
            "input_tokens": response.usage_metadata.get('input_tokens', 0),
            "output_tokens": response.usage_metadata.get('output_tokens', 0),
            # ... rest of metrics
        })
    
    return True
    
async def batch_mark_completed(problem_dir):
    """Batch checkpoint writes instead of per-problem"""
    global _pending_completions
    
    async with COMPLETED_LOCK:
        if not _pending_completions:
            return
            
        COMPLETED_PROBLEMS.update(_pending_completions)
        _pending_completions = []
        
        checkpoint_file = os.path.join(problem_dir, "completed_problems.json")
        completed_data = {
            "problems": list(COMPLETED_PROBLEMS),
            "last_updated": datetime.now().isoformat(),
            "total_completed": len(COMPLETED_PROBLEMS)
        }
        
        async with aiofiles.open(checkpoint_file, "w", encoding="utf-8") as f:
            await f.write(json.dumps(completed_data, indent=2))
            
async def mark_problem_completed(task_id, source, problem_dir):
    """
    Mark a problem as completed and save to checkpoint file
    """
    problem_key = f"{source}/{task_id}"
    
    async with COMPLETED_LOCK:
        COMPLETED_PROBLEMS.add(problem_key)
        
        # Save to checkpoint file
        checkpoint_file = os.path.join(problem_dir, "completed_problems.json")
        completed_data = {
            "problems": list(COMPLETED_PROBLEMS),
            "last_updated": datetime.now().isoformat(),
            "total_completed": len(COMPLETED_PROBLEMS)
        }
        
        async with aiofiles.open(checkpoint_file, "w", encoding="utf-8") as f:
            await f.write(json.dumps(completed_data, indent=2))

async def load_completed_problems(problem_dir):
    """
    Load previously completed problems from checkpoint file
    """
    checkpoint_file = os.path.join(problem_dir, "completed_problems.json")
    
    if not os.path.exists(checkpoint_file):
        print("📝 No checkpoint file found. Starting fresh.")
        return set()
    
    try:
        async with aiofiles.open(checkpoint_file, "r", encoding="utf-8") as f:
            content = await f.read()
            data = json.loads(content)
            completed = set(data.get("problems", []))
            print(f"✅ Loaded {len(completed)} completed problems from checkpoint")
            print(f"   Last updated: {data.get('last_updated', 'unknown')}")
            return completed
    except Exception as e:
        print(f"⚠️ Error loading checkpoint file: {e}")
        return set()

def format_escaped_text(text):
    """
    Removes escape characters from text and formats code blocks in markdown.
    
    Args:
        text: String with escaped characters
        
    Returns:
        Formatted string with escape characters removed
    """
    # Replace escaped underscores
    text = text.replace('\\_', '_')
    
    # Replace double backslash-n with newline
    text = text.replace('\\\\n', '\n')
    
    # Replace single backslash-n with newline
    text = text.replace('\\n', '\n')
    
    # Replace escaped quotes
    text = text.replace('\\"', '"')
    text = text.replace("\\'", "'")
    
    # Replace any remaining double backslashes
    text = text.replace('\\\\', '')
    
    return text
        
async def write_cocotb_testbench(filepath: str, testbench_code: str, encoding: str = "utf-8") -> None:
    """
    Write CocoTB testbench code to file with proper escape sequence handling.
    Handles both single (\\n) and double (\\\\n) escaped newlines.
    """
    text = testbench_code  
    '''
    # Step 1: Handle escaped quotes within strings first
    # \\" in the middle of text (not at string boundaries)
    text = re.sub(r'\\\\(["\'])', r'\1', text)
    
    # Step 2: Handle newlines and tabs
    text = text.replace('\\\\n', '\n')
    text = text.replace('\\n', '\n')
    text = text.replace('\\\\t', '\t')
    text = text.replace('\\t', '\t')
    text = text.replace('\\r', '\r')
    
    # Step 3: Handle remaining escaped quotes
    text = text.replace('\\"', '"')
    text = text.replace("\\'", "'")
    
    # Step 4: Handle escaped underscores
    text = text.replace('\\_', '_')
    
    # Step 5: Handle escaped asterisks
    text = text.replace('\\*', '*')
    '''
    async with aiofiles.open(filepath, 'w', encoding=encoding) as f:
        await f.write(text)
    
    print(f"✅ Written: {filepath}")
        
async def process_problem(row, test_folder, problem_dir, semaphore):
    """
    Optimized: Parallel file writes, single semaphore, batched checkpoints
    """
    task_id = str(row['task_id'])
    source = row['source']
    verilog_prompt = row['verilog_prompt']
    cocotb_testbench = row['cocotb_testbench']
    
    working_dir = os.path.join(test_folder, source, task_id)
    os.makedirs(working_dir, exist_ok=True)  # Fast enough to be sync
    
    testbench_filename = os.path.join(working_dir, f"{task_id}_testbench.py")
    prompt_filename = os.path.join(working_dir, f"{task_id}_prompt.txt")
    
    # Run file writes AND LLM calls concurrently
    file_tasks = [
        write_cocotb_testbench(testbench_filename, cocotb_testbench),
        write_prompt_file(prompt_filename, verilog_prompt),
    ]
    
    llm_tasks = [
        run_and_log(task_id, source, working_dir, verilog_prompt, semaphore, i)
        for i in range(K)
    ]
    
    # All concurrent
    all_results = await asyncio.gather(*file_tasks, *llm_tasks, return_exceptions=True)
    
    # Check LLM results (skip file task results)
    llm_results = all_results[len(file_tasks):]
    successes = sum(1 for r in llm_results if r is True)
    
    if successes > 0:
        async with COMPLETED_LOCK:
            _pending_completions.append(f"{source}/{task_id}")
            if len(_pending_completions) >= CHECKPOINT_BATCH_SIZE:
                await batch_mark_completed(problem_dir)  
                
async def write_prompt_file(filepath, content):
    """Helper for parallel file writes"""
    async with aiofiles.open(filepath, "w", encoding="utf-8") as f:
        await f.write(content)
        
async def periodic_tasks(problem_dir, interval=30):
    """Combined periodic task for metrics + checkpoints"""
    while True:
        await asyncio.sleep(interval)
        
        # Save metrics
        async with METRICS_LOCK:
            if METRICS_LOG:
                metrics_df = pd.DataFrame(METRICS_LOG)
                metrics_df.to_csv(os.path.join(problem_dir, "metrics_log.csv"), index=False)
        
        # Flush pending checkpoints
        await batch_mark_completed(problem_dir)
        
async def save_metrics_periodically(problem_dir, interval=30):
    """
    Periodically save metrics to disk every `interval` seconds
    """
    while True:
        await asyncio.sleep(interval)
        async with METRICS_LOCK:
            if METRICS_LOG:
                metrics_df = pd.DataFrame(METRICS_LOG)
                metrics_df.to_csv(os.path.join(problem_dir, "metrics_log.csv"), index=False)
                print(f"\n💾 Auto-saved metrics ({len(METRICS_LOG)} entries)")

async def main():
    dataset_file = r'C:\Users\durgamaniryudh\Desktop\Learn\testing_evals\verifyverilog.parquet'
    problem_dir = os.path.dirname(dataset_file)
    test_folder = os.path.join(problem_dir, 'test')
    os.makedirs(test_folder, exist_ok=True)
    
    global COMPLETED_PROBLEMS
    COMPLETED_PROBLEMS = await load_completed_problems(problem_dir)
    
    df = pd.read_parquet(dataset_file)
    
    # Optimized filtering (vectorized string concat)
    df['problem_key'] = df['source'].astype(str) + '/' + df['task_id'].astype(str)
    df_filtered = df[~df['problem_key'].isin(COMPLETED_PROBLEMS)].copy()
    df_filtered = df_filtered.drop('problem_key', axis=1)
    
    if len(df_filtered) == 0:
        print("✅ All problems already completed!")
        return
    
    # Single semaphore is cleaner
    semaphore = asyncio.Semaphore(MAX_CONCURRENT_LLM_CALLS)
    
    # Start periodic tasks
    periodic_task = asyncio.create_task(periodic_tasks(problem_dir, interval=30))
    
    tasks = [
        process_problem(row, test_folder, problem_dir, semaphore)
        for _, row in df_filtered.iterrows()
    ]
    
    try:
        for coro in async_tqdm(asyncio.as_completed(tasks), total=len(tasks), desc="Processing"):
            await coro
    finally:
        periodic_task.cancel()
        await batch_mark_completed(problem_dir)  # Final flush
        
        async with METRICS_LOCK:
            if METRICS_LOG:
                pd.DataFrame(METRICS_LOG).to_csv(
                    os.path.join(problem_dir, "metrics_log.csv"), index=False
                )
    
    print("\n✅ All problems processed!")
    print(f"📊 Metrics log saved to: {os.path.join(problem_dir, 'metrics_log.csv')}")
    print(f"📁 Generated files saved to: {test_folder}")
    print(f"📈 Total problems completed this run: {len(df_filtered)}")
    print(f"📈 Total problems completed overall: {len(COMPLETED_PROBLEMS)}")

if __name__ == "__main__":
    asyncio.run(main())