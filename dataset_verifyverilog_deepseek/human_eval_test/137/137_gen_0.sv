module compare_numbers(
  input wire clk,
  input wire rst_n,
  input wire [39:0] a_str,
  input wire [1:0] a_type,
  input wire [39:0] b_str,
  input wire [1:0] b_type,
  input wire start,
  output reg [39:0] result_str,
  output reg [1:0] result_type,
  output reg done,
  output reg none
);
  
  // Stage 1 registers
  reg [39:0] s1_a_str;
  reg [1:0]  s1_a_type;
  reg [39:0] s1_b_str;
  reg [1:0]  s1_b_type;
  reg s1_valid;
  
  // Parsing structures
  typedef struct packed {
    logic [39:0]   orig_str;
    logic [1:0]    orig_type;
    logic          is_negative;
    logic [9:0]    int_part;
    logic [7:0]    frac_digits;
    logic          invalid;
  } parse_result_t;
  
  // Stage 2 registers
  parse_result_t s2_a, s2_b;
  reg s2_valid;
  
  // Fixed-point registers
  typedef struct packed {
    logic [39:0]   orig_str;
    logic [1:0]    orig_type;
    logic [15:0]   fixed_val;
  } fp_result_t;
  
  // Stage 3/4/5 registers
  fp_result_t s3_a, s3_b;
  fp_result_t s4_a, s4_b;
  reg [3:0] pipeline;
  
  // -------------------------
  // Combinational processing
  // -------------------------
  
  // Parse single string
  function automatic parse_result_t parse_str(
    input logic [39:0] str,
    input logic [1:0]  str_type
  );
    logic [39:0] clean_str;
    logic [7:0]  chars[5];
    parse_result_t res;
    
    res.orig_str  = str;
    res.orig_type = str_type;
    res.invalid   = 0;
    res.int_part  = 0;
    res.frac_digits = 0;
    res.is_negative = 0;
    
    // Clean commas for string type
    clean_str = str;
    if (str_type == 2) begin
      for (int i=0; i<5; i++) begin
        if (str[i*8 +:8] == ",") clean_str[i*8 +:8] = ".";
      end
    end
    
    // Extract characters
    for (int i=0; i<5; i++) begin
      chars[i] = clean_str[i*8 +:8];
    end
    
    // Parse loop
    int ptr = 0;
    int state = 0; // 0=int, 1=frac
    int int_cnt = 0;
    int frac_cnt = 0;
    
    // Handle sign
    if (chars[0] == "-") begin
      res.is_negative = 1;
      ptr = 1;
    end
    
    for (int i=ptr; i<5; i++) begin
      if (chars[i] == 0) break; // Null terminator
      
      if (chars[i] == ".") begin
        if (state == 1) res.invalid = 1; // Multiple dots
        state = 1;
        continue;
      end
      
      if (chars[i] >= "0" && chars[i] <= "9") begin
        logic [7:0] digit = chars[i] - "0";
        
        if (state == 0) begin // Integer part
          if (int_cnt < 3) begin
            res.int_part = res.int_part * 10 + digit;
            int_cnt++;
          end
          else res.invalid = 1; // Overflow
        end
        else begin // Fractional part
          if (frac_cnt < 2) begin
            res.frac_digits = res.frac_digits * 10 + digit;
            frac_cnt++;
          end
          else res.invalid = 1; // Overflow
        end
      end
      else if (chars[i] != 0) begin
        res.invalid = 1; // Invalid char
      end
    end
    
    // Check empty input
    if (int_cnt + frac_cnt == 0) res.invalid = 1;
    return res;
  endfunction
  
  // Fixed-point conversion
  function automatic logic [15:0] to_fixed(input parse_result_t r);
    logic [15:0] int_val, frac_val;
    
    if (r.invalid) return 0;
    
    // Clamp integer range
    if ((!r.is_negative && r.int_part > 127) ||
        ( r.is_negative && r.int_part > 128))
     return 0;
    
    // Integer: left shift 8 bits (Q8.8)
    int_val = r.int_part << 8;
    
    // Fraction: (digits*256+50)/100
    frac_val = (r.frac_digits * 256 + 50) / 100;
    
    // Add and apply sign
    if (r.is_negative)
      return ~(int_val + frac_val) + 1; // Two's complement
    else
      return int_val + frac_val;
  endfunction
  
  // -------------------------
  // Pipeline processing
  // -------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_valid <= 0;
      s2_valid <= 0;
      pipeline <= 0;
      done <= 0;
      none <= 0;
      result_str <= 0;
      result_type <= 0;
    end
    else begin
      // Stage 1: Input registration
      if (start) begin
        s1_a_str  <= a_str;
        s1_a_type <= a_type;
        s1_b_str  <= b_str;
        s1_b_type <= b_type;
        s1_valid  <= 1;
      end
      else begin
        s1_valid <= 0;
      end
      
      // Stage 2: Parsing
      s2_valid <= s1_valid;
      s2_a <= parse_str(s1_a_str, s1_a_type);
      s2_b <= parse_str(s1_b_str, s1_b_type);
      
      // Stage 3: Fixed-point conversion
      s3_a.orig_str  <= s2_a.orig_str;
      s3_a.orig_type <= s2_a.orig_type;
      s3_a.fixed_val <= to_fixed(s2_a);
      
      s3_b.orig_str  <= s2_b.orig_str;
      s3_b.orig_type <= s2_b.orig_type;
      s3_b.fixed_val <= to_fixed(s2_b);
      
      // Stage 4: Pipeline
      s4_a <= s3_a;
      s4_b <= s3_b;
      
      // Stage 5: Comparision and output
      pipeline <= {pipeline[2:0], s1_valid}; // Shift pipeline
      
      if (pipeline[3]) begin // 5th cycle
        done <= 1;
        
        if (s4_a.fixed_val == s4_b.fixed_val) begin
          none <= 1;
          result_str <= 0;
          result_type <= 0;
        end
        else if ($signed(s4_a.fixed_val) > $signed(s4_b.fixed_val)) begin
          none <= 0;
          result_str <= s4_a.orig_str;
          result_type <= s4_a.orig_type;
        end
        else begin
          none <= 0;
          result_str <= s4_b.orig_str;
          result_type <= s4_b.orig_type;
        end
      end
      else begin
        done <= 0;
        none <= 0;
      end
    end
  end
endmodule