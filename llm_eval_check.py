#!/usr/bin/env python3

"""
SystemVerilog Benchmark Compilation and Verification Script
Checks iverilog compilation and cocotb verification for benchmark folders

Folder structure:
  parent_folder/
    category_1/
      problem_1/
        xxx_gen_x_.sv, xxx_testbench.py, xxx_prompt.txt
      problem_2/
        ...
    category_2/
      ...

File patterns: *_gen_*.sv, *_prompt.txt, *_testbench.py
"""

import os
import subprocess
import json
import time
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import argparse
import sys
import psutil


class BenchmarkVerifier:

    def __init__(self, parent_folder: str, output_dir: str = "results"):
        self.parent_folder = Path(parent_folder)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Progress tracking file
        self.progress_file = self.output_dir / "progress.json"
        
        # Load previous progress (includes full results)
        self.progress_data = self.load_progress()
        
        # Metrics storage - restore from progress or start fresh
        self.results = self.progress_data.get('results', {
            'timestamp': datetime.now().isoformat(),
            'parent_folder': str(self.parent_folder),
            'total_tests': 0,
            'compilation_pass': 0,
            'compilation_fail': 0,
            'verification_pass': 0,
            'verification_fail': 0,
            'skipped': 0,
            'skipped_previously_completed': 0,
            'missing_files': 0,
            'test_details': [],
            'category_summary': {}  # Per-category stats
        })
        
        # Track completed folder paths for quick lookup (category/problem format)
        self.completed_folders = set(self.progress_data.get('completed_folders', []))

    def load_progress(self) -> Dict:
        """Load progress and full results from progress file"""
        if self.progress_file.exists():
            try:
                with open(self.progress_file, 'r') as f:
                    data = json.load(f)
                    completed_count = len(data.get('completed_folders', []))
                    print(f"📂 Loaded progress: {completed_count} problems already processed")
                    
                    # Validate that progress is for the same parent folder
                    if data.get('parent_folder') != str(self.parent_folder):
                        print(f"⚠ Warning: Progress file is for different folder. Starting fresh.")
                        return {}
                    
                    return data
            except (json.JSONDecodeError, Exception) as e:
                print(f"⚠ Warning: Could not load progress file: {e}")
                return {}
        return {}

    def save_progress(self):
        """Save current progress and full results to progress file"""
        progress_data = {
            'parent_folder': str(self.parent_folder),
            'last_updated': datetime.now().isoformat(),
            'completed_folders': list(self.completed_folders),
            'results': self.results
        }
        
        with open(self.progress_file, 'w') as f:
            json.dump(progress_data, f, indent=2)

    def reset_progress(self):
        """Clear all progress and start fresh"""
        self.completed_folders = set()
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'parent_folder': str(self.parent_folder),
            'total_tests': 0,
            'compilation_pass': 0,
            'compilation_fail': 0,
            'verification_pass': 0,
            'verification_fail': 0,
            'skipped': 0,
            'skipped_previously_completed': 0,
            'missing_files': 0,
            'test_details': [],
            'category_summary': {}
        }
        if self.progress_file.exists():
            self.progress_file.unlink()
        print("🔄 Progress reset - will process all folders")

    def discover_problem_folders(self) -> List[Tuple[Path, str, str]]:
        """
        Discover all problem folders in the nested structure.
        Returns list of tuples: (problem_path, category_name, problem_name)
        """
        problem_folders = []
        
        # Get all category folders (first level subdirectories)
        category_folders = [
            f for f in self.parent_folder.iterdir()
            if f.is_dir() and not f.name.startswith('.') and not f.name.startswith('_')
        ]
        category_folders.sort()
        
        for category_folder in category_folders:
            # Get all problem folders within each category
            problem_subfolders = [
                f for f in category_folder.iterdir()
                if f.is_dir() and not f.name.startswith('.') and not f.name.startswith('_')
            ]
            problem_subfolders.sort()
            
            for problem_folder in problem_subfolders:
                problem_folders.append((
                    problem_folder,
                    category_folder.name,
                    problem_folder.name
                ))
        
        return problem_folders

    def get_folder_key(self, category: str, problem: str) -> str:
        """Generate a unique key for a problem folder"""
        return f"{category}/{problem}"

    def find_benchmark_files(self, subfolder: Path) -> Tuple[Optional[Path], Optional[Path], Optional[Path]]:
        """
        Find benchmark files in a subfolder
        Returns: (sv_file, testbench_file, prompt_file)
        """
        # Find HDL module file: *_gen_*.sv
        sv_files = list(subfolder.glob("*_gen_*.sv"))
        sv_file = sv_files[0] if sv_files else None
        
        # Find testbench file: *_testbench.py
        tb_files = list(subfolder.glob("*_testbench.py"))
        tb_file = tb_files[0] if tb_files else None
        
        # Find prompt file: *_prompt.txt
        prompt_files = list(subfolder.glob("*_prompt.txt"))
        prompt_file = prompt_files[0] if prompt_files else None
        
        return sv_file, tb_file, prompt_file

    def extract_module_name(self, sv_file: Path) -> str:
        """Extract module name from SystemVerilog file"""
        try:
            with open(sv_file, 'r') as f:
                content = f.read()
                # Look for module declaration
                match = re.search(r'module\s+(\w+)\s*[#(;]', content)
                if match:
                    return match.group(1)
        except Exception as e:
            print(f"    Warning: Could not extract module name: {e}")
        
        # Fallback to filename without _gen_x_ pattern
        name = sv_file.stem
        name = re.sub(r'_gen_\d+_', '', name)
        return name

    def compile_with_iverilog(self, sv_file: Path, work_dir: Path) -> Dict:
        """Compile SystemVerilog file with iverilog"""
        result = {
            'status': 'unknown',
            'stdout': '',
            'stderr': '',
            'duration': 0,
            'command': ''
        }
        
        if not sv_file:
            result['status'] = 'skipped'
            result['stderr'] = 'No SystemVerilog file found'
            return result
        
        # Build iverilog command
        output_file = work_dir / "design.vvp"
        cmd = ['iverilog', '-g2012', '-o', str(output_file), str(sv_file)]
        result['command'] = ' '.join(cmd)
        
        start_time = time.time()
        try:
            proc = subprocess.run(
                cmd,
                cwd=work_dir,
                capture_output=True,
                text=True,
                timeout=60
            )
            result['duration'] = time.time() - start_time
            result['stdout'] = proc.stdout
            result['stderr'] = proc.stderr
            result['status'] = 'pass' if proc.returncode == 0 else 'fail'
            result['returncode'] = proc.returncode
            
        except subprocess.TimeoutExpired:
            result['duration'] = time.time() - start_time
            result['status'] = 'timeout'
            result['stderr'] = 'Compilation timeout (60s)'
        except Exception as e:
            result['duration'] = time.time() - start_time
            result['status'] = 'error'
            result['stderr'] = str(e)
        
        return result

    def kill_proc_tree(self, pid, timeout=5):
        """Kill a process tree on any platform"""
        if pid is None:
            return
        try:
            print(f"kill:{pid}")
            parent = psutil.Process(pid)
            children = parent.children(recursive=True)
            
            # Kill children first
            for child in children:
                try:
                    child.kill()
                except psutil.NoSuchProcess:
                    pass
            
            # Kill parent
            try:
                parent.kill()
            except psutil.NoSuchProcess:
                pass
            
            # Wait for all to terminate
            gone, alive = psutil.wait_procs([parent] + children, timeout=timeout)
            
            # Force kill any remaining
            for p in alive:
                try:
                    p.kill()
                except psutil.NoSuchProcess:
                    pass
                    
        except psutil.NoSuchProcess:
            pass

    def run_cocotb_test(self, work_dir: Path, tb_file: Path, sv_file: Path) -> Dict:
        result = {
            'status': 'unknown',
            'stdout': '',
            'stderr': '',
            'duration': 0,
            'test_results': {},
            'command': ''
        }
        
        module_name = self.extract_module_name(sv_file)
        self.create_cocotb_makefile(work_dir, tb_file, sv_file, module_name)
        
        cmd = ['make']
        result['command'] = ' '.join(cmd)
        
        start_time = time.time()
        proc = None
        
        try:
            # Clean previous runs
            subprocess.run(['make', 'clean'], cwd=work_dir, capture_output=True, timeout=10)
            
            proc = subprocess.Popen(
                cmd,
                cwd=work_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env={**os.environ, 'SIM': 'icarus'}
            )
            print(f"    Created process: {proc.pid}")
            try:
                stdout, stderr = proc.communicate(timeout=300)
                result['stdout'] = stdout
                result['stderr'] = stderr
                result['returncode'] = proc.returncode
                
                output = stdout + stderr
                if 'passed' in output.lower() and proc.returncode == 0:
                    result['status'] = 'pass'
                elif 'failed' in output.lower() or proc.returncode != 0:
                    result['status'] = 'fail'
                else:
                    result['status'] = 'unknown'
                    
                # Extract test statistics
                passed_match = re.search(r'(\d+)\s+passed', output, re.IGNORECASE)
                failed_match = re.search(r'(\d+)\s+failed', output, re.IGNORECASE)
                
                if passed_match:
                    result['test_results']['passed'] = int(passed_match.group(1))
                if failed_match:
                    result['test_results']['failed'] = int(failed_match.group(1))
                    
            except subprocess.TimeoutExpired:
                if proc and proc.pid is not None:
                    print(f"    Timeout, killing: {proc.pid}")
                    self.kill_proc_tree(proc.pid)
                result['status'] = 'timeout'
                result['stderr'] = 'Test timeout (300s)'
                
        except Exception as e:
            if proc and proc.pid is not None:
                self.kill_proc_tree(proc.pid)
            result['status'] = 'error'
            result['stderr'] = str(e)
        
        result['duration'] = time.time() - start_time
        return result

    def create_cocotb_makefile(self, work_dir: Path, tb_file: Path, sv_file: Path, module_name: str):
        """Create a Makefile for cocotb testing"""
        
        makefile_content = f"""# Cocotb Makefile - Auto-generated
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
PWD := $(shell pwd)

# Source files
VERILOG_SOURCES = $(PWD)/{sv_file.name}

# Top level module
TOPLEVEL = {module_name}

# Python test module
MODULE = {tb_file.stem}

# SystemVerilog support
COMPILE_ARGS += -g2012

# Include cocotb's make rules
include $(shell cocotb-config --makefiles)/Makefile.sim
"""
        
        with open(work_dir / "Makefile", 'w') as f:
            f.write(makefile_content)

    def update_category_summary(self, category: str, test_result: Dict):
        """Update per-category statistics"""
        if category not in self.results['category_summary']:
            self.results['category_summary'][category] = {
                'total': 0,
                'compilation_pass': 0,
                'compilation_fail': 0,
                'verification_pass': 0,
                'verification_fail': 0,
                'missing_files': 0
            }
        
        stats = self.results['category_summary'][category]
        stats['total'] += 1
        
        status = test_result['overall_status']
        if status == 'pass':
            stats['compilation_pass'] += 1
            stats['verification_pass'] += 1
        elif status == 'compilation_failed':
            stats['compilation_fail'] += 1
        elif status == 'verification_failed':
            stats['compilation_pass'] += 1
            stats['verification_fail'] += 1
        elif status.startswith('missing'):
            stats['missing_files'] += 1

    def process_problem_folder(self, problem_path: Path, category: str, problem: str, 
                                index: int, total_pending: int) -> Dict:
        """Process a single problem folder"""
        folder_key = self.get_folder_key(category, problem)
        
        print(f"\n{'='*70}")
        print(f"Processing [{index}/{total_pending}]: {folder_key}")
        print(f"{'='*70}")
        
        test_result = {
            'index': index,
            'category': category,
            'problem_name': problem,
            'folder_key': folder_key,
            'relative_path': str(problem_path.relative_to(self.parent_folder)),
            'absolute_path': str(problem_path),
            'processed_at': datetime.now().isoformat(),
            'files': {
                'sv_file': None,
                'testbench_file': None,
                'prompt_file': None
            },
            'compilation': {},
            'verification': {},
            'overall_status': 'unknown'
        }
        
        # Find files
        sv_file, tb_file, prompt_file = self.find_benchmark_files(problem_path)
        
        test_result['files']['sv_file'] = sv_file.name if sv_file else None
        test_result['files']['testbench_file'] = tb_file.name if tb_file else None
        test_result['files']['prompt_file'] = prompt_file.name if prompt_file else None
        
        print(f"  Category: {category}")
        print(f"  Problem:  {problem}")
        print(f"  Files found:")
        print(f"    HDL Module:  {sv_file.name if sv_file else 'NOT FOUND'}")
        print(f"    Testbench:   {tb_file.name if tb_file else 'NOT FOUND'}")
        print(f"    Prompt:      {prompt_file.name if prompt_file else 'NOT FOUND'}")
        
        # Check if required files exist
        if not sv_file:
            print(f"  ⚠ Error: No HDL module file (*_gen_*.sv) found!")
            test_result['overall_status'] = 'missing_hdl'
            self.results['missing_files'] += 1
            return test_result
        
        if not tb_file:
            print(f"  ⚠ Error: No testbench file (*_testbench.py) found!")
            test_result['overall_status'] = 'missing_testbench'
            self.results['missing_files'] += 1
            return test_result
        
        # Extract module name
        module_name = self.extract_module_name(sv_file)
        print(f"  Module name: {module_name}")
        
        # Compilation check
        print(f"\n  [1/2] Compiling with iverilog...")
        compilation_result = self.compile_with_iverilog(sv_file, problem_path)
        test_result['compilation'] = compilation_result
        
        print(f"    Status: {compilation_result['status'].upper()}")
        print(f"    Duration: {compilation_result['duration']:.2f}s")
        
        if compilation_result['status'] != 'pass':
            error_preview = compilation_result['stderr'][:150].replace('\n', ' ')
            print(f"    Error: {error_preview}...")
            test_result['overall_status'] = 'compilation_failed'
            self.results['compilation_fail'] += 1
            return test_result
        
        self.results['compilation_pass'] += 1
        print(f"    ✓ Compilation successful")
        
        # Verification check (only if compilation passed)
        print(f"\n  [2/2] Running cocotb verification...")
        verification_result = self.run_cocotb_test(problem_path, tb_file, sv_file)
        test_result['verification'] = verification_result
        
        print(f"    Status: {verification_result['status'].upper()}")
        print(f"    Duration: {verification_result['duration']:.2f}s")
        
        if verification_result.get('test_results'):
            tr = verification_result['test_results']
            print(f"    Tests: {tr.get('passed', 0)} passed, {tr.get('failed', 0)} failed")
        
        if verification_result['status'] == 'pass':
            test_result['overall_status'] = 'pass'
            self.results['verification_pass'] += 1
            print(f"    ✓ Verification successful")
        else:
            test_result['overall_status'] = 'verification_failed'
            self.results['verification_fail'] += 1
            error_preview = verification_result['stderr'][:150].replace('\n', ' ')
            print(f"    ✗ Error: {error_preview}...")
        
        return test_result

    def run_benchmark(self, max_tests: int = None, category_filter: str = None):
        """Run the complete benchmark verification"""
        print(f"\n{'#'*70}")
        print(f"# SystemVerilog Benchmark Verification")
        print(f"# Parent folder: {self.parent_folder}")
        print(f"{'#'*70}\n")
        
        # Discover all problem folders
        all_problems = self.discover_problem_folders()
        
        # Apply category filter if specified
        if category_filter:
            all_problems = [p for p in all_problems if p[1] == category_filter]
            print(f"Filtering by category: {category_filter}")
        
        if max_tests:
            all_problems = all_problems[:max_tests]
        
        # Get unique categories
        categories = sorted(set(p[1] for p in all_problems))
        
        print(f"Found {len(all_problems)} total problems across {len(categories)} categories:")
        for cat in categories:
            cat_count = sum(1 for p in all_problems if p[1] == cat)
            print(f"  • {cat}: {cat_count} problems")
        
        # Filter out already completed folders
        pending_problems = [
            p for p in all_problems 
            if self.get_folder_key(p[1], p[2]) not in self.completed_folders
        ]
        skipped_count = len(all_problems) - len(pending_problems)
        
        print(f"\nProgress:")
        print(f"  Already completed: {skipped_count}")
        print(f"  Pending: {len(pending_problems)}\n")
        
        if skipped_count > 0:
            print(f"ℹ️  Use --reset to reprocess all folders\n")
        
        if len(pending_problems) == 0:
            print("✅ All problems have been processed. Use --reset to rerun.\n")
            # Still generate reports with existing data
            self.generate_reports()
            return
        
        start_time = time.time()
        
        # Process each pending problem
        for idx, (problem_path, category, problem) in enumerate(pending_problems, 1):
            self.results['total_tests'] += 1
            test_result = self.process_problem_folder(
                problem_path, category, problem, idx, len(pending_problems)
            )
            self.results['test_details'].append(test_result)
            
            # Update category summary
            self.update_category_summary(category, test_result)
            
            # Mark as completed and save progress after each folder
            folder_key = self.get_folder_key(category, problem)
            self.completed_folders.add(folder_key)
            self.save_progress()
            
            # Print running totals
            print(f"\n  📊 Running totals: {self.results['verification_pass']} pass, "
                  f"{self.results['verification_fail']} fail, "
                  f"{self.results['compilation_fail']} compile errors, "
                  f"{self.results['missing_files']} missing files")
        
        # Update duration (cumulative)
        session_duration = time.time() - start_time
        previous_duration = self.results.get('total_duration', 0)
        self.results['total_duration'] = previous_duration + session_duration
        self.results['last_session_duration'] = session_duration
        
        # Save final progress
        self.save_progress()
        
        # Generate reports
        self.generate_reports()

    def generate_reports(self):
        """Generate summary and detailed reports"""
        print(f"\n{'#'*70}")
        print("# CUMULATIVE SUMMARY REPORT")
        print(f"{'#'*70}\n")
        
        print(f"Total Problems Processed: {self.results['total_tests']}")
        print(f"Missing Files:            {self.results['missing_files']}")
        print(f"\nCompilation Results:")
        print(f"  ✓ Pass:                 {self.results['compilation_pass']}")
        print(f"  ✗ Fail:                 {self.results['compilation_fail']}")
        print(f"\nVerification Results:")
        print(f"  ✓ Pass:                 {self.results['verification_pass']}")
        print(f"  ✗ Fail:                 {self.results['verification_fail']}")
        
        # Per-category summary
        if self.results.get('category_summary'):
            print(f"\n{'─'*70}")
            print("Per-Category Summary:")
            print(f"{'─'*70}")
            print(f"{'Category':<30} {'Total':>8} {'Comp✓':>8} {'Comp✗':>8} {'Ver✓':>8} {'Ver✗':>8} {'Pass%':>8}")
            print(f"{'─'*70}")
            
            for category in sorted(self.results['category_summary'].keys()):
                stats = self.results['category_summary'][category]
                pass_rate = (stats['verification_pass'] / stats['total'] * 100) if stats['total'] > 0 else 0
                print(f"{category:<30} {stats['total']:>8} {stats['compilation_pass']:>8} "
                      f"{stats['compilation_fail']:>8} {stats['verification_pass']:>8} "
                      f"{stats['verification_fail']:>8} {pass_rate:>7.1f}%")
        
        # Calculate percentages
        if self.results['total_tests'] > 0:
            comp_rate = (self.results['compilation_pass'] / self.results['total_tests']) * 100
            verif_rate = (self.results['verification_pass'] / self.results['total_tests']) * 100
            
            print(f"\n{'─'*70}")
            print(f"Overall Compilation Success Rate:  {comp_rate:.1f}%")
            print(f"Overall Verification Success Rate: {verif_rate:.1f}%")
            print(f"Total Duration (all runs):         {self.results.get('total_duration', 0):.2f}s")
            if 'last_session_duration' in self.results:
                print(f"This Session Duration:             {self.results['last_session_duration']:.2f}s")
        
        # Save detailed JSON report
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        json_file = self.output_dir / f"benchmark_results_{timestamp}.json"
        with open(json_file, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"\n{'─'*70}")
        print(f"📄 Detailed JSON results: {json_file}")
        
        # Also save/update a "latest" results file
        latest_json = self.output_dir / "benchmark_results_latest.json"
        with open(latest_json, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"📄 Latest results:        {latest_json}")
        
        # Generate CSV summary
        csv_file = self.generate_csv_summary(timestamp)
        print(f"📊 CSV summary:           {csv_file}")
        
        # Generate per-category CSV
        category_csv = self.generate_category_csv(timestamp)
        print(f"📊 Category summary:      {category_csv}")
        
        # Generate error report
        error_file = self.generate_error_report(timestamp)
        print(f"📝 Error report:          {error_file}")
        
        print(f"{'─'*70}\n")

    def generate_csv_summary(self, timestamp: str) -> Path:
        """Generate CSV summary of results"""
        csv_file = self.output_dir / f"summary_{timestamp}.csv"
        
        with open(csv_file, 'w') as f:
            # Header
            f.write("Index,Category,Problem,HDL_File,TB_File,Prompt_File,Compilation,Verification,Overall,Comp_Time,Verif_Time,Processed_At\n")
            
            # Data rows - sorted by category then problem name
            sorted_details = sorted(
                self.results['test_details'], 
                key=lambda x: (x.get('category', ''), x.get('problem_name', ''))
            )
            
            for idx, test in enumerate(sorted_details, 1):
                category = test.get('category', 'unknown')
                problem = test.get('problem_name', test.get('folder_name', 'unknown'))
                hdl_file = test['files']['sv_file'] or 'MISSING'
                tb_file = test['files']['testbench_file'] or 'MISSING'
                prompt_file = test['files']['prompt_file'] or 'MISSING'
                comp_status = test['compilation'].get('status', 'N/A')
                verif_status = test['verification'].get('status', 'N/A') if test['verification'] else 'N/A'
                comp_time = test['compilation'].get('duration', 0)
                verif_time = test['verification'].get('duration', 0) if test['verification'] else 0
                processed_at = test.get('processed_at', 'N/A')
                
                f.write(f"{idx},{category},{problem},{hdl_file},{tb_file},{prompt_file},"
                       f"{comp_status},{verif_status},{test['overall_status']},{comp_time:.2f},{verif_time:.2f},{processed_at}\n")
        
        # Also save latest CSV
        latest_csv = self.output_dir / "summary_latest.csv"
        with open(csv_file, 'r') as src:
            with open(latest_csv, 'w') as dst:
                dst.write(src.read())
        
        return csv_file

    def generate_category_csv(self, timestamp: str) -> Path:
        """Generate per-category summary CSV"""
        csv_file = self.output_dir / f"category_summary_{timestamp}.csv"
        
        with open(csv_file, 'w') as f:
            f.write("Category,Total,Compilation_Pass,Compilation_Fail,Verification_Pass,Verification_Fail,Missing_Files,Pass_Rate\n")
            
            for category in sorted(self.results.get('category_summary', {}).keys()):
                stats = self.results['category_summary'][category]
                pass_rate = (stats['verification_pass'] / stats['total'] * 100) if stats['total'] > 0 else 0
                f.write(f"{category},{stats['total']},{stats['compilation_pass']},{stats['compilation_fail']},"
                       f"{stats['verification_pass']},{stats['verification_fail']},{stats['missing_files']},{pass_rate:.1f}\n")
        
        # Also save latest
        latest_csv = self.output_dir / "category_summary_latest.csv"
        with open(csv_file, 'r') as src:
            with open(latest_csv, 'w') as dst:
                dst.write(src.read())
        
        return csv_file

    def generate_error_report(self, timestamp: str) -> Path:
        """Generate detailed error report for failed tests"""
        error_file = self.output_dir / f"errors_{timestamp}.txt"
        
        with open(error_file, 'w') as f:
            f.write("="*70 + "\n")
            f.write("ERROR REPORT - Failed Tests (Cumulative)\n")
            f.write("="*70 + "\n\n")
            
            failed_tests = [t for t in self.results['test_details'] 
                          if t['overall_status'] not in ['pass']]
            
            # Sort by category then problem name
            failed_tests = sorted(
                failed_tests, 
                key=lambda x: (x.get('category', ''), x.get('problem_name', ''))
            )
            
            f.write(f"Total Failed Tests: {len(failed_tests)}\n")
            f.write(f"Total Passed Tests: {self.results['verification_pass']}\n")
            f.write(f"Total Tests: {self.results['total_tests']}\n\n")
            
            # Group by category
            current_category = None
            
            for idx, test in enumerate(failed_tests, 1):
                category = test.get('category', 'unknown')
                
                if category != current_category:
                    current_category = category
                    f.write(f"\n{'#'*70}\n")
                    f.write(f"# CATEGORY: {category}\n")
                    f.write(f"{'#'*70}\n")
                
                f.write(f"\n{'='*70}\n")
                f.write(f"[{idx}] {test.get('folder_key', test.get('problem_name', 'unknown'))}\n")
                f.write(f"{'='*70}\n")
                f.write(f"Overall Status: {test['overall_status']}\n")
                f.write(f"Processed At: {test.get('processed_at', 'N/A')}\n")
                f.write(f"HDL File: {test['files']['sv_file']}\n")
                f.write(f"Testbench: {test['files']['testbench_file']}\n")
                f.write(f"Prompt: {test['files']['prompt_file']}\n\n")
                
                if test['overall_status'].startswith('missing'):
                    f.write("MISSING FILES ERROR:\n")
                    f.write("-"*70 + "\n")
                    if not test['files']['sv_file']:
                        f.write("✗ Missing HDL module file (*_gen_*.sv)\n")
                    if not test['files']['testbench_file']:
                        f.write("✗ Missing testbench file (*_testbench.py)\n")
                    f.write("\n")
                
                if test['compilation'].get('status') == 'fail':
                    f.write("COMPILATION ERROR:\n")
                    f.write("-"*70 + "\n")
                    f.write(f"Command: {test['compilation'].get('command', 'N/A')}\n")
                    f.write(f"Duration: {test['compilation'].get('duration', 0):.2f}s\n")
                    f.write(f"\nStderr:\n{test['compilation'].get('stderr', 'N/A')}\n")
                    f.write(f"\nStdout:\n{test['compilation'].get('stdout', 'N/A')}\n\n")
                
                if test['verification'].get('status') in ['fail', 'timeout', 'error']:
                    f.write("VERIFICATION ERROR:\n")
                    f.write("-"*70 + "\n")
                    f.write(f"Status: {test['verification'].get('status', 'N/A')}\n")
                    f.write(f"Duration: {test['verification'].get('duration', 0):.2f}s\n")
                    f.write(f"\nStderr:\n{test['verification'].get('stderr', 'N/A')}\n")
                    f.write(f"\nStdout:\n{test['verification'].get('stdout', 'N/A')}\n\n")
        
        # Also save latest error report
        latest_errors = self.output_dir / "errors_latest.txt"
        with open(error_file, 'r') as src:
            with open(latest_errors, 'w') as dst:
                dst.write(src.read())
        
        return error_file


def main():
    parser = argparse.ArgumentParser(
        description='SystemVerilog Benchmark Compilation and Verification Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Expected folder structure:
  parent_folder/
    category_1/
      problem_1/
        xxx_gen_x_.sv       (HDL module file)
        xxx_testbench.py    (cocotb testbench)
        xxx_prompt.txt      (specification file)
      problem_2/
        ...
    category_2/
      problem_3/
        ...

Progress tracking:
  - Progress is automatically saved after each test
  - Rerun the command to continue from where you left off
  - Use --reset to start fresh
  - Use --status to view current progress without running tests
  - Use --category to filter by a specific category
        """
    )
    parser.add_argument(
        'parent_folder',
        help='Parent folder containing benchmark category subfolders'
    )
    parser.add_argument(
        '-o', '--output',
        default='results',
        help='Output directory for results (default: results)'
    )
    parser.add_argument(
        '-n', '--max-tests',
        type=int,
        help='Maximum number of tests to run'
    )
    parser.add_argument(
        '-c', '--category',
        type=str,
        help='Only run tests from a specific category'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    parser.add_argument(
        '--reset',
        action='store_true',
        help='Reset progress and reprocess all folders'
    )
    parser.add_argument(
        '--status',
        action='store_true',
        help='Show current progress status without running tests'
    )
    
    args = parser.parse_args()
    
    # Check if parent folder exists
    if not os.path.isdir(args.parent_folder):
        print(f"❌ Error: Parent folder '{args.parent_folder}' does not exist!")
        sys.exit(1)
    
    # Create verifier
    verifier = BenchmarkVerifier(args.parent_folder, args.output)
    
    # Status only mode
    if args.status:
        print(f"\n{'#'*70}")
        print("# PROGRESS STATUS")
        print(f"{'#'*70}\n")
        
        # Discover all problem folders
        all_problems = verifier.discover_problem_folders()
        categories = sorted(set(p[1] for p in all_problems))
        
        completed = len(verifier.completed_folders)
        total = len(all_problems)
        pending = total - completed
        
        print(f"Total problems:    {total}")
        print(f"Categories:        {len(categories)}")
        print(f"Completed:         {completed}")
        print(f"Pending:           {pending}")
        print(f"Progress:          {(completed/total*100) if total > 0 else 0:.1f}%\n")
        
        # Per-category status
        print(f"{'─'*70}")
        print("Per-Category Progress:")
        print(f"{'─'*70}")
        print(f"{'Category':<30} {'Total':>10} {'Done':>10} {'Pending':>10} {'Progress':>10}")
        print(f"{'─'*70}")
        
        for cat in categories:
            cat_problems = [p for p in all_problems if p[1] == cat]
            cat_completed = sum(1 for p in cat_problems 
                               if verifier.get_folder_key(p[1], p[2]) in verifier.completed_folders)
            cat_pending = len(cat_problems) - cat_completed
            cat_progress = (cat_completed / len(cat_problems) * 100) if cat_problems else 0
            print(f"{cat:<30} {len(cat_problems):>10} {cat_completed:>10} {cat_pending:>10} {cat_progress:>9.1f}%")
        
        if verifier.results['total_tests'] > 0:
            print(f"\n{'─'*70}")
            print("Cumulative Results:")
            print(f"  Compilation Pass:   {verifier.results['compilation_pass']}")
            print(f"  Compilation Fail:   {verifier.results['compilation_fail']}")
            print(f"  Verification Pass:  {verifier.results['verification_pass']}")
            print(f"  Verification Fail:  {verifier.results['verification_fail']}")
            print(f"  Missing Files:      {verifier.results['missing_files']}")
        
        sys.exit(0)
    
    # Reset if requested
    if args.reset:
        verifier.reset_progress()
    
    # Run benchmark
    verifier.run_benchmark(max_tests=args.max_tests, category_filter=args.category)


if __name__ == "__main__":
    main()