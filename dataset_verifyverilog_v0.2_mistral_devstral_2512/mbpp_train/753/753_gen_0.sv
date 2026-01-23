module min_k_records (
  input clk,
  input rst_n,
  input start,
  input [3:0] K,
  input [31:0] name_0, name_1, name_2, name_3,
  input [7:0] score_0, score_1, score_2, score_3,
  output reg [31:0] out_name_0, out_name_1, out_name_2, out_name_3,
  output reg [7:0] out_score_0, out_score_1, out_score_2, out_score_3,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SORT,
    OUTPUT,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers for sorting network
  reg [31:0] s_name_0, s_name_1, s_name_2, s_name_3;
  reg [7:0] s_score_0, s_score_1, s_score_2, s_score_3;

  // Stage 1 registers
  reg [31:0] s1_name_0, s1_name_1, s1_name_2, s1_name_3;
  reg [7:0] s1_score_0, s1_score_1, s1_score_2, s1_score_3;

  // Stage 2 registers
  reg [31:0] s2_name_0, s2_name_1, s2_name_2, s2_name_3;
  reg [7:0] s2_score_0, s2_score_1, s2_score_2, s2_score_3;

  // Stage 3 registers
  reg [31:0] s3_name_0, s3_name_1, s3_name_2, s3_name_3;
  reg [7:0] s3_score_0, s3_score_1, s3_score_2, s3_score_3;

  // Counter for output stage
  reg [1:0] count;

  // Compare and swap function
  function automatic void compare_swap(
    input [31:0] in_name_a, in_name_b,
    input [7:0] in_score_a, in_score_b,
    output [31:0] out_name_a, out_name_b,
    output [7:0] out_score_a, out_score_b
  );
    if (in_score_a > in_score_b) begin
      out_name_a = in_name_b;
      out_score_a = in_score_b;
      out_name_b = in_name_a;
      out_score_b = in_score_a;
    end else begin
      out_name_a = in_name_a;
      out_score_a = in_score_a;
      out_name_b = in_name_b;
      out_score_b = in_score_b;
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      count <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SORT;
      end
      SORT: begin
        if (count == 3) next_state = OUTPUT;
      end
      OUTPUT: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Stage 1: Compare adjacent pairs (0-1, 2-3)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_name_0 <= 0; s1_name_1 <= 0; s1_name_2 <= 0; s1_name_3 <= 0;
      s1_score_0 <= 0; s1_score_1 <= 0; s1_score_2 <= 0; s1_score_3 <= 0;
    end else if (state == SORT && count == 0) begin
      compare_swap(name_0, name_1, score_0, score_1, s1_name_0, s1_name_1, s1_score_0, s1_score_1);
      compare_swap(name_2, name_3, score_2, score_3, s1_name_2, s1_name_3, s1_score_2, s1_score_3);
    end
  end

  // Stage 2: Compare cross pairs (0-2, 1-3)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s2_name_0 <= 0; s2_name_1 <= 0; s2_name_2 <= 0; s2_name_3 <= 0;
      s2_score_0 <= 0; s2_score_1 <= 0; s2_score_2 <= 0; s2_score_3 <= 0;
    end else if (state == SORT && count == 1) begin
      compare_swap(s1_name_0, s1_name_2, s1_score_0, s1_score_2, s2_name_0, s2_name_2, s2_score_0, s2_score_2);
      compare_swap(s1_name_1, s1_name_3, s1_score_1, s1_score_3, s2_name_1, s2_name_3, s2_score_1, s2_score_3);
    end
  end

  // Stage 3: Compare adjacent pairs (1-2)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s3_name_0 <= 0; s3_name_1 <= 0; s3_name_2 <= 0; s3_name_3 <= 0;
      s3_score_0 <= 0; s3_score_1 <= 0; s3_score_2 <= 0; s3_score_3 <= 0;
    end else if (state == SORT && count == 2) begin
      s3_name_0 = s2_name_0;
      s3_score_0 = s2_score_0;
      compare_swap(s2_name_1, s2_name_2, s2_score_1, s2_score_2, s3_name_1, s3_name_2, s3_score_1, s3_score_2);
      s3_name_3 = s2_name_3;
      s3_score_3 = s2_score_3;
    end
  end

  // Output stage
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_name_0 <= 0; out_name_1 <= 0; out_name_2 <= 0; out_name_3 <= 0;
      out_score_0 <= 0; out_score_1 <= 0; out_score_2 <= 0; out_score_3 <= 0;
      done <= 0;
    end else if (state == OUTPUT) begin
      case (K)
        4'b0001: begin
          out_name_0 <= s3_name_0;
          out_score_0 <= s3_score_0;
          out_name_1 <= 0; out_name_2 <= 0; out_name_3 <= 0;
          out_score_1 <= 0; out_score_2 <= 0; out_score_3 <= 0;
        end
        4'b0010: begin
          out_name_0 <= s3_name_0;
          out_score_0 <= s3_score_0;
          out_name_1 <= s3_name_1;
          out_score_1 <= s3_score_1;
          out_name_2 <= 0; out_name_3 <= 0;
          out_score_2 <= 0; out_score_3 <= 0;
        end
        4'b0011: begin
          out_name_0 <= s3_name_0;
          out_score_0 <= s3_score_0;
          out_name_1 <= s3_name_1;
          out_score_1 <= s3_score_1;
          out_name_2 <= s3_name_2;
          out_score_2 <= s3_score_2;
          out_name_3 <= 0;
          out_score_3 <= 0;
        end
        4'b0100: begin
          out_name_0 <= s3_name_0;
          out_score_0 <= s3_score_0;
          out_name_1 <= s3_name_1;
          out_score_1 <= s3_score_1;
          out_name_2 <= s3_name_2;
          out_score_2 <= s3_score_2;
          out_name_3 <= s3_name_3;
          out_score_3 <= s3_score_3;
        end
        default: begin
          out_name_0 <= 0; out_name_1 <= 0; out_name_2 <= 0; out_name_3 <= 0;
          out_score_0 <= 0; out_score_1 <= 0; out_score_2 <= 0; out_score_3 <= 0;
        end
      endcase
      done <= 1;
    end else if (state == IDLE) begin
      done <= 0;
    end
  end

  // Counter for sorting stages
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
    end else if (state == SORT) begin
      count <= count + 1;
    end else begin
      count <= 0;
    end
  end

endmodule