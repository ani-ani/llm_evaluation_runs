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
METRICS_LOG = []
COMPLETED_PROBLEMS = set()  # Track completed problems
METRICS_LOCK = asyncio.Lock()  # Thread-safe metrics logging
COMPLETED_LOCK = asyncio.Lock()  # Thread-safe completion logging
K = 1

# Semaphore to limit concurrent problem processing
MAX_CONCURRENT_PROBLEMS = 10  # Adjust based on API rate limits
MAX_CONCURRENT_CALLS = 10  # Adjust based on API rate limits

model = ChatOpenAI(
        openai_api_key=getenv("OPENROUTER_API_KEY"),
        openai_api_base=getenv("OPENROUTER_BASE_URL"),
        #model_name="tngtech/deepseek-r1t2-chimera:free",
        #model_name="anthropic/claude-sonnet-4.5",
        #model_name="x-ai/grok-code-fast-1",
        #model_name="minimax/minimax-m2:free",
        #model_name="openrouter/polaris-alpha",
        model_name="xiaomi/mimo-v2-flash:free",
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
    model_name="mistralai/mistral-small-3.1-24b-instruct:free"
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

async def run_and_log(task_id, source, working_dir, user_prompt, semaphore_llm_calls, i):
    """
    Run evaluation for a single iteration and log metrics
    """
    async with semaphore_llm_calls:

        PARSER_PROMPT = "Extract the verilog code in the given text below and return as asked.\
                        The code format might not be json compatable, fix the formating issues so json.loads() will work without issues."
        
        response = await run_eval(user_prompt)

        if response is None:
            print(f"Failed to get response for {task_id}, iteration {i}")
            return
        
        # Save the generated Verilog code
        verilog_filename = os.path.join(working_dir, f"{task_id}_gen_{i}.sv")
        async with aiofiles.open(verilog_filename, "w", encoding="utf-8") as f:
            try:
                code = extract_code_from_llm_output(response.content)
            except:  # using second model supporting structured output to parse output of bigger model
                try:
                    #structured_parser_model = parser_model.with_structured_output(code_output) 
                    parse_message = PARSER_PROMPT + "\n" + response.content
                    code_output_result = await call_model_with_retry(structured_parser_model, parse_message) 
                    code = code_output_result["code"]
                except Exception as e:
                    print(f"Failed to parse code for {task_id}, iteration {i}: {e}")
                    code = f"// Failed to parse code\n{response.content}"
            await f.write(code)

        # Extract metrics from response
        input_tokens = response.usage_metadata.get('input_tokens', 0)
        output_tokens = response.usage_metadata.get('output_tokens', 0)
        reasoning_tokens = response.usage_metadata.get('output_token_details', {}).get('reasoning', 0)
        model_name = response.response_metadata.get('model_name', '')
        finish_reason = response.response_metadata.get('finish_reason', '')
        system_fingerprint = response.response_metadata.get('system_fingerprint', '')
        run_id = response.response_metadata.get('id', '')

        # Thread-safe metrics logging
        async with METRICS_LOCK:
            METRICS_LOG.append({
                "task_id": task_id,
                "source": source,
                "iteration": i,
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "reasoning_tokens": reasoning_tokens,
                "verilog_file": verilog_filename,
                "model_name": model_name,
                "finish_reason": finish_reason,
                "system_fingerprint": system_fingerprint,
                "run_id": run_id,
            })

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
        
async def process_problem(row, test_folder, problem_dir, semaphore_problem, semaphore_llm_calls):
    
    # Processing phase (with semaphore)
    async with semaphore_problem:
        task_id = str(row['task_id'])
        source = row['source']
        problem_key = f"{source}/{task_id}"
        verilog_prompt = row['verilog_prompt']
        cocotb_testbench = row['cocotb_testbench']
        
        # Setup phase (no semaphore needed)
        working_dir = os.path.join(test_folder, source, task_id)
        await asyncio.get_event_loop().run_in_executor(
            None, lambda: os.makedirs(working_dir, exist_ok=True)
        )
        
        # Save the cocotb testbench file (once per problem)
        testbench_filename = os.path.join(working_dir, f"{task_id}_testbench.py")
        await write_cocotb_testbench(testbench_filename, cocotb_testbench)
        
        # Save the original prompt for reference
        prompt_filename = os.path.join(working_dir, f"{task_id}_prompt.txt")
        async with aiofiles.open(prompt_filename, "w", encoding="utf-8") as f:
            #formated_text = format_escaped_text(verilog_prompt)
            formated_text = verilog_prompt
            await f.write(formated_text)
    
        tasks = [
            run_and_log(task_id, source, working_dir, verilog_prompt, semaphore_llm_calls, i)
            for i in range(K)
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Check for successes
        successes = sum(1 for r in results if not isinstance(r, Exception))
        
        if successes > 0:
            await mark_problem_completed(task_id, source, problem_dir)
        else:
            print(f"❌ All {K} iterations failed for {problem_key}")
            
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
    
    # Create test folder if it doesn't exist
    os.makedirs(test_folder, exist_ok=True)
    
    # Load previously completed problems
    global COMPLETED_PROBLEMS
    COMPLETED_PROBLEMS = await load_completed_problems(problem_dir)
    
    # Load dataset
    df = pd.read_parquet(dataset_file)
    print(f"\n📊 Loaded dataset with {len(df)} problems")
    print(f"Columns: {df.columns.tolist()}\n")
    
    # Filter out already completed problems
    df['problem_key'] = df['source'] + '/' + str(df['task_id'])
    df_filtered = df[~df['problem_key'].isin(COMPLETED_PROBLEMS)].copy()
    df_filtered = df_filtered.drop('problem_key', axis=1)
    
    skipped_count = len(df) - len(df_filtered)
    if skipped_count > 0:
        print(f"⏭️  Skipping {skipped_count} already completed problems")
    print(f"🚀 Processing {len(df_filtered)} remaining problems\n")
    
    if len(df_filtered) == 0:
        print("✅ All problems already completed!")
        return
    
    # Create semaphore to limit concurrent problem processing
    semaphore_problem = asyncio.Semaphore(MAX_CONCURRENT_PROBLEMS)
    semaphore_llm_calls = asyncio.Semaphore(MAX_CONCURRENT_CALLS)
    
    # Start periodic metrics saving task
    save_task = asyncio.create_task(save_metrics_periodically(problem_dir, interval=30))
    
    # Process all problems in parallel (limited by semaphore)
    
    #df_filtered = df_filtered
    tasks = [
        process_problem(row, test_folder, problem_dir, semaphore_problem, semaphore_llm_calls)
        for idx, row in df_filtered.iterrows()
    ]
    
    try:
        #await asyncio.gather(*tasks)
        completed = 0
        for coro in async_tqdm(asyncio.as_completed(tasks), total=len(tasks), desc="Processing"):
            result = await coro
            completed += 1
            
    finally:
        # Cancel periodic save task
        save_task.cancel()
        try:
            await save_task
        except asyncio.CancelledError:
            pass

        async with METRICS_LOCK:
            if METRICS_LOG:
                metrics_df = pd.DataFrame(METRICS_LOG)
                metrics_df.to_csv(os.path.join(problem_dir, "metrics_log.csv"), index=False)
    
    print("\n✅ All problems processed!")
    print(f"📊 Metrics log saved to: {os.path.join(problem_dir, 'metrics_log.csv')}")
    print(f"📁 Generated files saved to: {test_folder}")
    print(f"📈 Total problems completed this run: {len(df_filtered)}")
    print(f"📈 Total problems completed overall: {len(COMPLETED_PROBLEMS)}")

if __name__ == "__main__":
    asyncio.run(main())