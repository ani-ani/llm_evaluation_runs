module lang_divider (
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [1:0] m,
  input [15:0] grid_data,
  output reg valid,
  output reg [15:0] lang_a,
  output reg [15:0] lang_b,
  output reg [15:0] lang_c,
  output reg impossible_flag
);
  
  reg [1:0] cnt;
  wire [15:0] p1_lang_a, p1_lang_b, p1_lang_c;
  wire [15:0] p2_lang_a, p2_lang_b, p2_lang_c;
  wire [15:0] p3_lang_a, p3_lang_b, p3_lang_c;
  wire p1_valid, p2_valid, p3_valid;
  
  // Pattern 1: Column-based split
  assign p1_lang_a[ 0] = (0 < n) && (0 < m) && (0 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 1] = (0 < n) && (1 < m) && (1 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 2] = (0 < n) && (2 < m) && (2 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 3] = (0 < n) && (3 < m) && (3 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 4] = (1 < n) && (0 < m) && (0 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 5] = (1 < n) && (1 < m) && (1 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 6] = (1 < n) && (2 < m) && (2 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 7] = (1 < n) && (3 < m) && (3 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 8] = (2 < n) && (0 < m) && (0 < ((m+2'd2)/3'd2));
  assign p1_lang_a[ 9] = (2 < n) && (1 < m) && (1 < ((m+2'd2)/3'd2));
  assign p1_lang_a[10] = (2 < n) && (2 < m) && (2 < ((m+2'd2)/3'd2));
  assign p1_lang_a[11] = (2 < n) && (3 < m) && (3 < ((m+2'd2)/3'd2));
  assign p1_lang_a[12] = (3 < n) && (0 < m) && (0 < ((m+2'd2)/3'd2));
  assign p1_lang_a[13] = (3 < n) && (1 < m) && (1 < ((m+2'd2)/3'd2));
  assign p1_lang_a[14] = (3 < n) && (2 < m) && (2 < ((m+2'd2)/3'd2));
  assign p1_lang_a[15] = (3 < n) && (3 < m) && (3 < ((m+2'd2)/3'd2));
  
  wire [1:0] m_div = m / 3;
  assign p1_lang_b = {16{
    (0 >= (((m+2'd2)/3'd2)) && 0 < m-((m+2'd2)/3'd2)-(m_div)) ||
    (1 >= (((m+2'd2)/3'd2)) && 1 < m-((m+2'd2)/3'd2)-(m_div)) ||
    (2 >= (((m+2'd2)/3'd2)) && 2 < m-((m+2'd2)/3'd2)-(m_div)) ||
    (3 >= (((m+2'd2)/3'd2)) && 3 < m-((m+2'd2)/3'd2)-(m_div))
  }} & {16{1'b1}};
  
  assign p1_lang_c = {16{
    (0 >= m-((m+2'd2)/3'd2)-(m_div)) ||
    (1 >= m-((m+2'd2)/3'd2)-(m_div)) ||
    (2 >= m-((m+2'd2)/3'd2)-(m_div)) ||
    (3 >= m-((m+2'd2)/3'd2)-(m_div))
  }} & {16{1'b1}};
  
  // Pattern 2: Row-based split
  assign p2_lang_a[ 0] = (0 < ((n+2'd2)/3'd2)) && (0 < n) && (0 < m);
  assign p2_lang_a[ 1] = (0 < ((n+2'd2)/3'd2)) && (0 < n) && (1 < m);
  assign p2_lang_a[ 2] = (0 < ((n+2'd2)/3'd2)) && (0 < n) && (2 < m);
  assign p2_lang_a[ 3] = (0 < ((n+2'd2)/3'd2)) && (0 < n) && (3 < m);
  assign p2_lang_a[ 4] = (1 < ((n+2'd2)/3'd2)) && (1 < n) && (0 < m);
  assign p2_lang_a[ 5] = (1 < ((n+2'd2)/3'd2)) && (1 < n) && (1 < m);
  assign p2_lang_a[ 6] = (1 < ((n+2'd2)/3'd2)) && (1 < n) && (2 < m);
  assign p2_lang_a[ 7] = (1 < ((n+2'd2)/3'd2)) && (1 < n) && (3 < m);
  assign p2_lang_a[ 8] = (2 < ((n+2'd2)/3'd2)) && (2 < n) && (0 < m);
  assign p2_lang_a[ 9] = (2 < ((n+2'd2)/3'd2)) && (2 < n) && (1 < m);
  assign p2_lang_a[10] = (2 < ((n+2'd2)/3'd2)) && (2 < n) && (2 < m);
  assign p2_lang_a[11] = (2 < ((n+2'd2)/3'd2)) && (2 < n) && (3 < m);
  assign p2_lang_a[12] = (3 < ((n+2'd2)/3'd2)) && (3 < n) && (0 < m);
  assign p2_lang_a[13] = (3 < ((n+2'd2)/3'd2)) && (3 < n) && (1 < m);
  assign p2_lang_a[14] = (3 < ((n+2'd2)/3'd2)) && (3 < n) && (2 < m);
  assign p2_lang_a[15] = (3 < ((n+2'd2)/3'd2)) && (3 < n) && (3 < m);
  
  wire [1:0] n_div = n / 3;
  assign p2_lang_b = {16{
    (0 >= (((n+2'd2)/3'd2)) && 0 < n-((n+2'd2)/3'd2)-(n_div)) ||
    (1 >= (((n+2'd2)/3'd2)) && 1 < n-((n+2'd2)/3'd2)-(n_div)) ||
    (2 >= (((n+2'd2)/3'd2)) && 2 < n-((n+2'd2)/3'd2)-(n_div)) ||
    (3 >= (((n+2'd2)/3'd2)) && 3 < n-((n+2'd2)/3'd2)-(n_div))
  }} & {16{1'b1}};
  
  assign p2_lang_c = {16{
    (0 >= n-((n+2'd2)/3'd2)-(n_div)) ||
    (1 >= n-((n+2'd2)/3'd2)-(n_div)) ||
    (2 >= n-((n+2'd2)/3'd2)-(n_div)) ||
    (3 >= n-((n+2'd2)/3'd2)-(n_div))
  }} & {16{1'b1}};
  
  // Pattern 3: Border vs inner
  generate
    genvar i;
    for (i=0; i<16; i=i+1) begin : border_gen
      assign p3_lang_a[i] = (((i/4 == 0) || (i/4 == (n-1)) || (i%4 == 0) || (i%4 == (m-1))) && (i/4 < n) && (i%4 < m));
      assign p3_lang_b[i] = (!((i/4 == 0) || (i/4 == (n-1)) || (i%4 == 0) || (i%4 == (m-1))) && (i/4 < n) && (i%4 < m));
    end
  endgenerate
  assign p3_lang_c = 16'd0;
  
  // Validity checks:
  // Check cell requirements: 1=EXACTLY one language, 2=AT LEAST two languages
  function automatic bit check_cells (input [15:0] g_data, input [15:0] a, input [15:0] b, input [15:0] c);
    for (int i=0; i<16; i++) begin
      // Skip unassigned cells
      if (g_data[i] == 1'b1) begin
        if ((a[i] && b[i]) || (a[i] && c[i]) || (b[i] && c[i])) return 0; // Multiple langs for 1's
        if (!(a[i] || b[i] || c[i])) return 0; // No lang for 1's
      end else if (g_data[i] == 1'b0) begin
        if ((a[i] + b[i] + c[i]) < 2) return 0; // Need ≥2 langs for 2's
      end
    end
    return 1;
  endfunction
  
  assign p1_valid = check_cells(grid_data, p1_lang_a, p1_lang_b, p1_lang_c);
  assign p2_valid = check_cells(grid_data, p2_lang_a, p2_lang_b, p2_lang_c);
  assign p3_valid = check_cells(grid_data, p3_lang_a, p3_lang_b, p3_lang_c);
  
  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid <= 1'b0;
      lang_a <= 16'd0;
      lang_b <= 16'd0;
      lang_c <= 16'd0;
      impossible_flag <= 1'b0;
      cnt <= 2'd0;
    end else begin
      if (start) begin
        if (cnt >= 2'd2) begin
          valid <= 1'b1;
          if (p1_valid) begin
            lang_a <= p1_lang_a;
            lang_b <= p1_lang_b;
            lang_c <= p1_lang_c;
            impossible_flag <= 1'b0;
          end else if (p2_valid) begin
            lang_a <= p2_lang_a;
            lang_b <= p2_lang_b;
            lang_c <= p2_lang_c;
            impossible_flag <= 1'b0;
          end else if (p3_valid) begin
            lang_a <= p3_lang_a;
            lang_b <= p3_lang_b;
            lang_c <= p3_lang_c;
            impossible_flag <= 1'b0;
          end else begin
            impossible_flag <= 1'b1;
          end
        end else begin
          cnt <= cnt + 1'b1;
        end
      end else begin
        valid <= 1'b0;
        lang_a <= 16'd0;
        lang_b <= 16'd0;
        lang_c <= 16'd0;
        impossible_flag <= 1'b0;
        cnt <= 2'd0;
      end
    end
  end
endmodule