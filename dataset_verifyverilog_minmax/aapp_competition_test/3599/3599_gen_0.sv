module break_scheduler(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input [3:0] T, // concert length (4 bits, 0-15)
  input [2:0] N, // number of musicians (3 bits, max 5)
  input [4:0][3:0] breaks, // 5x4-bit break lengths (packed for 5 musicians)
  output reg [4:0][3:0] start_times, // 5x4-bit start times
  output reg done // high when computation complete
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE = 2'b10;

  // State registers
  reg [1:0] state;
  reg [3:0] counter;
  reg [3:0] T_reg;
  reg [2:0] N_reg;
  reg [4:0][3:0] breaks_reg;
  reg [15:0] current_1_break_minutes; // 1 break per minute
  reg [15:0] current_2_break_minutes; // 2 breaks per minute
  reg [4:0][3:0] temp_start_times; // temporary start times

  // Temporary variables
  reg [3:0] b; // break length for current musician
  reg [4:0] i; // current musician index
  integer s; // temporary for start time
  reg [15:0] candidate_cover; // candidate break cover
  reg found_valid; // flag for valid start time found
  reg [4:0][3:0] output_start_times; // final output start times

  // State machine and logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      counter <= 4'd0;
      T_reg <= 4'd0;
      N_reg <= 3'd0;
      breaks_reg <= 5'd0;
      current_1_break_minutes <= 16'd0;
      current_2_break_minutes <= 16'd0;
      temp_start_times <= 5'd0;
      output_start_times <= 5'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            counter <= 4'd0;
            T_reg <= T;
            N_reg <= N;
            breaks_reg <= breaks;
            current_1_break_minutes <= 16'd0;
            current_2_break_minutes <= 16'd0;
            temp_start_times <= 5'd0;
            done <= 1'b0;
          end
        end
        
        COMPUTE: begin
          counter <= counter + 1;
          
          if (counter < 5) begin
            i = counter;
            if (i < N_reg) begin
              b = breaks_reg[i];
            end else begin
              b = 4'd0;
            end
            
            if (b == 4'd0) begin
              temp_start_times[i] = 4'd0;
            end else begin
              found_valid = 1'b0;
              for (s = 0; s < 16; s = s + 1) begin
                if (s <= (T_reg - b)) begin
                  candidate_cover = ((16'h1 << b) - 1) << s;
                  if ((candidate_cover & current_2_break_minutes) == 16'd0) begin
                    temp_start_times[i] = s[3:0];
                    current_1_break_minutes = current_1_break_minutes ^ candidate_cover;
                    current_2_break_minutes = current_2_break_minutes | (current_1_break_minutes & candidate_cover);
                    found_valid = 1'b1;
                  end
                end
              end
              if (!found_valid) begin
                temp_start_times[i] = 4'd0;
              end
            end
          end
          
          if (counter == 10) begin
            state <= DONE;
            done <= 1'b1;
            output_start_times <= temp_start_times;
          end
        end
        
        DONE: begin
          // Maintain done until reset
        end
      endcase
    end
  end
  
  // Output assignment
  assign start_times = output_start_times;

endmodule