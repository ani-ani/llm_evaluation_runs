module grade_converter (
  input clk,
  input rst_n,
  input start,
  input [31:0] gpa_fixed,
  output reg [39:0] letter_grade,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPARE_1,
    COMPARE_2,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Threshold constants in Q16.16 format
  localparam [31:0] THRESHOLD_4_0 = 32'h00040000;
  localparam [31:0] THRESHOLD_3_7 = 32'h0003B333;
  localparam [31:0] THRESHOLD_3_3 = 32'h00034CCC;
  localparam [31:0] THRESHOLD_3_0 = 32'h00030000;
  localparam [31:0] THRESHOLD_2_7 = 32'h0002B333;
  localparam [31:0] THRESHOLD_2_3 = 32'h00024CCC;
  localparam [31:0] THRESHOLD_2_0 = 32'h00020000;
  localparam [31:0] THRESHOLD_1_7 = 32'h0001B333;
  localparam [31:0] THRESHOLD_1_3 = 32'h00014CCC;
  localparam [31:0] THRESHOLD_1_0 = 32'h00010000;
  localparam [31:0] THRESHOLD_0_7 = 32'h0000B333;
  localparam [31:0] THRESHOLD_0_0 = 32'h00000000;

  // Letter grade constants
  localparam [39:0] GRADE_A_PLUS = 40'h412B202020;
  localparam [39:0] GRADE_A = 40'h4120202020;
  localparam [39:0] GRADE_A_MINUS = 40'h412D202020;
  localparam [39:0] GRADE_B_PLUS = 40'h422B202020;
  localparam [39:0] GRADE_B = 40'h4220202020;
  localparam [39:0] GRADE_B_MINUS = 40'h422D202020;
  localparam [39:0] GRADE_C_PLUS = 40'h432B202020;
  localparam [39:0] GRADE_C = 40'h4320202020;
  localparam [39:0] GRADE_C_MINUS = 40'h432D202020;
  localparam [39:0] GRADE_D_PLUS = 40'h442B202020;
  localparam [39:0] GRADE_D = 40'h4420202020;
  localparam [39:0] GRADE_D_MINUS = 40'h442D202020;
  localparam [39:0] GRADE_E = 40'h4520202020;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMPARE_1;
      end
      COMPARE_1: next_state = COMPARE_2;
      COMPARE_2: next_state = DONE;
      DONE: begin
        if (start) next_state = COMPARE_1;
        else next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      letter_grade <= 40'h0000000000;
      done <= 1'b0;
    end else begin
      case (current_state)
        IDLE: begin
          letter_grade <= 40'h0000000000;
          done <= 1'b0;
        end
        COMPARE_1: begin
          letter_grade <= 40'h0000000000;
          done <= 1'b0;
        end
        COMPARE_2: begin
          letter_grade <= 40'h0000000000;
          done <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
          // Determine letter grade based on GPA
          if (gpa_fixed >= THRESHOLD_4_0) letter_grade <= GRADE_A_PLUS;
          else if (gpa_fixed >= THRESHOLD_3_7) letter_grade <= GRADE_A;
          else if (gpa_fixed >= THRESHOLD_3_3) letter_grade <= GRADE_A_MINUS;
          else if (gpa_fixed >= THRESHOLD_3_0) letter_grade <= GRADE_B_PLUS;
          else if (gpa_fixed >= THRESHOLD_2_7) letter_grade <= GRADE_B;
          else if (gpa_fixed >= THRESHOLD_2_3) letter_grade <= GRADE_B_MINUS;
          else if (gpa_fixed >= THRESHOLD_2_0) letter_grade <= GRADE_C_PLUS;
          else if (gpa_fixed >= THRESHOLD_1_7) letter_grade <= GRADE_C;
          else if (gpa_fixed >= THRESHOLD_1_3) letter_grade <= GRADE_C_MINUS;
          else if (gpa_fixed >= THRESHOLD_1_0) letter_grade <= GRADE_D_PLUS;
          else if (gpa_fixed >= THRESHOLD_0_7) letter_grade <= GRADE_D;
          else if (gpa_fixed > THRESHOLD_0_0) letter_grade <= GRADE_D_MINUS;
          else letter_grade <= GRADE_E;
        end
      endcase
    end
  end

endmodule