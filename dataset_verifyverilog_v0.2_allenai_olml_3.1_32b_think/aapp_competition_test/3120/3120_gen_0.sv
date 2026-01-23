module balloon_eq (
input clk,
input rst_n,
input start,
input [7:0] program_id,
input [7:0] node_type,
input [31:0] node_value,
input [7:0] child1_idx,
input [7:0] child2_idx,
input [7:0] num_nodes,
input node_valid,
output reg [1:0] result,
output reg done 
);

reg [2:0] state;
localparam IDLE = 3'b000, LOAD_A = 3'b001, LOAD_B = 3'b010, COMPUTE_A = 3'b011, COMPUTE_B = 3'b100, COMPARE = 3'b101, DONE = 3'b110;

reg [3:0] cycle_count;
reg [7:0] target_a, current_a;
reg [7:0] target_b, current_b;

reg [2:0] program_a_type [7:0];
reg [31:0] program_a_value [7:0];
reg [7:0] program_a_child1 [7:0];
reg [7:0] program_a_child2 [7:0];

reg [2:0] program_b_type [7:0];
reg [31:0] program_b_value [7:0];
reg [7:0] program_b_child1 [7:0];
reg [7:0] program_b_child2 [7:0];

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    cycle_count <= 4'd0;
    target_a <= 8'd0;
    current_a <= 8'd0;
    target_b <= 8'd0;
    current_b <= 8'd0;
    program_a_type[0] <= 3'd0; program_a_type[1] <= 3'd0; program_a_type[2] <= 3'd0; program_a_type[3] <= 3'd0;
    program_a_type[4] <= 3'd0; program_a_type[5] <= 3'd0; program_a_type[6] <= 3'd0; program_a_type[7] <= 3'd0;
    program_a_value[0] <= 32'd0; program_a_value[1] <= 32'd0; program_a_value[2] <= 32'd0; program_a_value[3] <= 32'd0;
    program_a_value[4] <= 32'd0; program_a_value[5] <= 32'd0; program_a_value[6] <= 32'd0; program_a_value[7] <= 32'd0;
    program_a_child1[0] <= 8'd0; program_a_child1[1] <= 8'd0; program_a_child1[2] <= 8'd0; program_a_child1[3] <= 8'd0;
    program_a_child1[4] <= 8'd0; program_a_child1[5] <= 8'd0; program_a_child1[6] <= 8'd0; program_a_child1[7] <= 8'd0;
    program_a_child2[0] <= 8'd0; program_a_child2[1] <= 8'd0; program_a_child2[2] <= 8'd0; program_a_child2[3] <= 8'd0;
    program_a_child2[4] <= 8'd0; program_a_child2[5] <= 8'd0; program_a_child2[6] <= 8'd0; program_a_child2[7] <= 8'd0;
    program_b_type[0] <= 3'd0; program_b_type[1] <= 3'd0; program_b_type[2] <= 3'd0; program_b_type[3] <= 3'd0;
    program_b_type[4] <= 3'd0; program_b_type[5] <= 3'd0; program_b_type[6] <= 3'd0; program_b_type[7] <= 3'd0;
    program_b_value[0] <= 32'd0; program_b_value[1] <= 32'd0; program_b_value[2] <= 32'd0; program_b_value[3] <= 32'd0;
    program_b_value[4] <= 32'd0; program_b_value[5] <= 32'd0; program_b_value[6] <= 32'd0; program_b_value[7] <= 32'd0;
    program_b_child1[0] <= 8'd0; program_b_child1[1] <= 8'd0; program_b_child1[2] <= 8'd0; program_b_child1[3] <= 8'd0;
    program_b_child1[4] <= 8'd0; program_b_child1[5] <= 8'd0; program_b_child1[6] <= 8'd0; program_b_child1[7] <= 8'd0;
    program_b_child2[0] <= 8'd0; program_b_child2[1] <= 8'd0; program_b_child2[2] <= 8'd0; program_b_child2[3] <= 8'd0;
    program_b_child2[4] <= 8'd0; program_b_child2[5] <= 8'd0; program_b_child2[6] <= 8'd0; program_b_child2[7] <= 8'd0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          cycle_count <= cycle_count + 1;
          if (cycle_count == 4'd10) begin
            done <= 1'b1;
            state <= DONE;
          end else begin
            state <= LOAD_A;
          end
        end
      end
      LOAD_A: begin
        if (program_id == 8'd0 && node_valid) begin
          if (current_a == 8'd0) target_a <= num_nodes;
          if (current_a < target_a) begin
            program_a_type[current_a] <= node_type;
            program_a_value[current_a] <= node_value;
            program_a_child1[current_a] <= child1_idx;
            program_a_child2[current_a] <= child2_idx;
            current_a <= current_a + 1;
          end
          if (current_a == target_a) state <= LOAD_B;
        end
      end
      LOAD_B: begin
        if (program_id == 8'd1 && node_valid) begin
          if (current_b == 8'd0) target_b <= num_nodes;
          if (current_b < target_b) begin
            program_b_type[current_b] <= node_type;
            program_b_value[current_b] <= node_value;
            program_b_child1[current_b] <= child1_idx;
            program_b_child2[current_b] <= child2_idx;
            current_b <= current_b + 1;
          end
          if (current_b == target_b) state <= COMPUTE_A;
        end
      end
      COMPUTE_A: begin
        state <= COMPUTE_B;
      end
      COMPUTE_B: begin
        state <= COMPARE;
      end
      COMPARE: begin
        // Do nothing
      end
      DONE: begin
        // Do nothing
      end
    endcase
  end
end

assign done = done;

endmodule