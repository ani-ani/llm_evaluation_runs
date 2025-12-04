module consecutive_subsequence_cost (
  input clk,              // clock
  input rst_n,            // active-low reset
  input start,            // start computation
  input [2:0] N,          // array size (1-8)
  input [7:0] element_0,  // array elements
  input [7:0] element_1,
  input [7:0] element_2,
  input [7:0] element_3,
  input [7:0] element_4,
  input [7:0] element_5,
  input [7:0] element_6,
  input [7:0] element_7,
  output reg [29:0] result,  // sum modulo 1e9 (last 9 digits)
  output reg done          // high when result ready
);

typedef enum logic [1:0] { IDLE, COMPUTE, FINISH } state_t;

state_t state;
reg [2:0] start_idx, end_idx;
reg [2:0] N_reg;
reg [7:0] elements_reg[0:7];
reg [29:0] accum_sum;
wire [7:0] current_min, current_max;
wire [3:0] length = end_idx - start_idx + 1;
wire [19:0] product = current_min * current_max * length;
wire [29:0] mod_sum = accum_sum + product;
wire [29:0] accum_sum_next = mod_sum >= 30'd1000000000 ? mod_sum - 30'd1000000000 : mod_sum;

// Find min/max for current subsequence
always_comb begin
  current_min = elements_reg[start_idx];
  current_max = elements_reg[start_idx];
  for (int i = start_idx + 1; i <= end_idx; i++) begin
    if (elements_reg[i] < current_min) current_min = elements_reg[i];
    if (elements_reg[i] > current_max) current_max = elements_reg[i];
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    result <= 0;
    accum_sum <= 0;
    start_idx <= 0;
    end_idx <= 0;
    N_reg <= 0;
    for (int i=0; i<8; i++) elements_reg[i] <= 0;
  end else case (state)
    IDLE: begin
      done <= 0;
      if (start) begin
        N_reg <= N;
        elements_reg[0] <= element_0;
        elements_reg[1] <= element_1;
        elements_reg[2] <= element_2;
        elements_reg[3] <= element_3;
        elements_reg[4] <= element_4;
        elements_reg[5] <= element_5;
        elements_reg[6] <= element_6;
        elements_reg[7] <= element_7;
        accum_sum <= 0;
        start_idx <= 0;
        end_idx <= 0;
        state <= COMPUTE;
      end
    end
    
    COMPUTE: begin
      accum_sum <= accum_sum_next;
      if (end_idx < (N_reg - 1)) begin        // Expand subsequence
        end_idx <= end_idx + 1;
      end else if (start_idx < (N_reg - 1)) begin // Move start
        start_idx <= start_idx + 1;
        end_idx <= start_idx + 1;
      end else begin                         // All subsequences done
        result <= accum_sum_next;
        done <= 1;
        state <= FINISH;
      end
    end
    
    FINISH: begin
      if (~start) begin
        state <= IDLE;
        done <= 0;
      end
    end
  endcase
end

endmodule