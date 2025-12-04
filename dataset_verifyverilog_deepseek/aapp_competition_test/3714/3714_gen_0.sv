module crush_joongoon (
  input clk,
  input rst_n,
  input start,
  input [2:0] crunch_arr [0:7],
  output reg [15:0] t,
  output reg done
);

  reg [3:0] state;
  localparam IDLE = 4'd0;
  localparam INIT = 4'd1;
  localparam FIND_CYCLES = 4'd2;
  localparam TRAVERSE = 4'd3;
  localparam CHECK_CYCLE = 4'd4;
  localparam SAVE_LENGTH = 4'd5;
  localparam INVALID_ST = 4'd6;
  localparam LCM_INIT = 4'd7;
  localparam LCM_LOOP = 4'd8;
  localparam GCD_COMPUTE = 4'd9;
  localparam LCM_UPDATE = 4'd10;
  localparam DONE_ST = 4'd11;

  reg [2:0] node_index;
  reg [2:0] start_node;
  reg [2:0] current_node;
  reg [3:0] path_length;
  reg [7:0] current_path;
  reg [7:0] visited;
  reg [3:0] lengths [0:7];
  reg [2:0] num_lengths;
  reg invalid_flag;
  reg [15:0] current_lcm;
  reg [2:0] length_index;
  reg [3:0] gcd_a;
  reg [3:0] gcd_b;
  reg [3:0] gcd_result;
  reg [7:0] mult_temp;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      t <= 16'd0;
      done <= 1'b0;
      visited <= 8'b0;
      current_path <= 8'b0;
      num_lengths <= 3'b0;
      invalid_flag <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 1'b0;
          end
        end
        INIT: begin
          visited <= 8'b0;
          current_path <= 8'b0;
          num_lengths <= 3'b0;
          invalid_flag <= 1'b0;
          t <= 16'd0;
          node_index <= 3'b0;
          state <= FIND_CYCLES;
        end
        FIND_CYCLES: begin
          if (node_index < 3'd7) begin
            if (!visited[node_index]) begin
              start_node <= node_index;
              current_node <= node_index;
              path_length <= 4'd0;
              current_path <= (8'd1 << node_index);
              visited[node_index] <= 1'b1;
              state <= TRAVERSE;
            end else begin
              node_index <= node_index + 3'd1;
            end
          end else begin
            if (invalid_flag) begin
              state <= INVALID_ST;
            end else if (num_lengths > 0) begin
              state <= LCM_INIT;
            end else begin
              state <= INVALID_ST;
            end
          end
        end
        TRAVERSE: begin
          current_node <= crunch_arr[current_node];
          path_length <= path_length + 4'd1;
          state <= CHECK_CYCLE;
        end
        CHECK_CYCLE: begin
          if (current_path[current_node]) begin
            if (current_node == start_node) begin
              if (path_length[0]) begin
                lengths[num_lengths] <= path_length;
              end else begin
                lengths[num_lengths] <= path_length >> 1;
              end
              num_lengths <= num_lengths + 1;
              state <= SAVE_LENGTH;
            end else begin
              invalid_flag <= 1'b1;
              state <= FIND_CYCLES;
            end
          end else if (visited[current_node]) begin
            invalid_flag <= 1'b1;
            state <= FIND_CYCLES;
          end else begin
            current_path <= current_path | (8'd1 << current_node);
            visited[current_node] <= 1'b1;
            if (path_length == 4'd7) begin
              invalid_flag <= 1'b1;
              state <= FIND_CYCLES;
            end else begin
              state <= TRAVERSE;
            end
          end
        end
        SAVE_LENGTH: begin
          current_path <= 8'b0;
          node_index <= node_index + 1;
          state <= FIND_CYCLES;
        end
        INVALID_ST: begin
          t <= 16'hFFFF;
          done <= 1'b1;
          state <= DONE_ST;
        end
        LCM_INIT: begin
          current_lcm <= 16'd1;
          length_index <= 3'd0;
          state <= LCM_LOOP;
        end
        LCM_LOOP: begin
          if (length_index < num_lengths) begin
            gcd_a <= current_lcm[3:0];
            gcd_b <= lengths[length_index];
            state <= GCD_COMPUTE;
          end else begin
            t <= current_lcm;
            done <= 1'b1;
            state <= DONE_ST;
          end
        end
        GCD_COMPUTE: begin
          if (gcd_b == 4'd0) begin
            gcd_result <= gcd_a;
            state <= LCM_UPDATE;
          end else begin
            gcd_a <= gcd_b;
            gcd_b <= gcd_a % gcd_b;
          end
        end
        LCM_UPDATE: begin
          mult_temp <= current_lcm[7:0] * lengths[length_index];
          current_lcm <= mult_temp / gcd_result;
          length_index <= length_index + 1;
          state <= LCM_LOOP;
        end
        DONE_ST: begin
          if (start) begin
            state <= INIT;
            done <= 1'b0;
          end else begin
            done <= 1'b1;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule