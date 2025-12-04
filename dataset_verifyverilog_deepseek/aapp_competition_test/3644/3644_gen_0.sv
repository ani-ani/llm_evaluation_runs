module hr_scheduler (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] fi [0:7],
  input [7:0] hi [0:7],
  output reg [3:0] min_hr_count,
  output reg [3:0] hr_assign [0:7],
  output reg done
);

typedef enum {
  IDLE,
  PROCESS_DAY,
  DONE
} state_t;

reg [3:0] stack [0:255];
reg [7:0] sp;
reg [3:0] max_hr_id;
reg [2:0] day_counter;
state_t state;

reg [15:0] conflict_bits;
reg [3:0] new_hr_id;
reg [7:0] new_sp_after_pop;

always_comb begin
  new_sp_after_pop = sp - fi[day_counter];
end

always_comb begin
  conflict_bits = 16'b0;
  for (int i=0; i < fi[day_counter]; i++) begin
    automatic int idx = sp - 1 - i;
    if (idx >= 0 && idx < 256) 
      conflict_bits[stack[idx]] = 1'b1;
  end
  new_hr_id = 4'b1111; 
  for (int i=0; i<16; i++) begin
    if (!conflict_bits[i]) begin
      new_hr_id = i;
      break;
    end
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    sp <= 8'b0;
    max_hr_id <= 4'b0;
    day_counter <= 3'b0;
    done <= 1'b0;
    for (int i=0; i<8; i++) hr_assign[i] <= 4'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          sp <= 8'b0;
          max_hr_id <= 4'b0;
          day_counter <= 3'b0;
          state <= PROCESS_DAY;
        end
      end

      PROCESS_DAY: begin
        if (day_counter < n) begin
          hr_assign[day_counter] <= new_hr_id;
          if (new_hr_id > max_hr_id)
            max_hr_id <= new_hr_id;
          
          sp <= new_sp_after_pop + hi[day_counter];
          
          for (int j=0; j < hi[day_counter]; j++) begin
            automatic int addr = new_sp_after_pop + j;
            if (addr < 256)
              stack[addr] <= new_hr_id;
          end
          
          day_counter <= day_counter + 1;
          
          if (day_counter + 1 == n)
            state <= DONE;
        end else
          state <= DONE;
      end

      DONE: begin
        done <= 1'b1;
        min_hr_count <= max_hr_id + 1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule