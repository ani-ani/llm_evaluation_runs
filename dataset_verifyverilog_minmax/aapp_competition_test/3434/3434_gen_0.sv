module explosion_probability(
  input clk,               // System clock
  input rst_n,             // Active-low reset
  input start,             // Start computation
  input [1:0] num_my_minions,  // Your minion count (0-2) - not used directly, health values determine presence
  input [1:0] num_opp_minions, // Opponent minion count (0-2) - not used directly, health values determine presence
  input [1:0] my_health_1, // Health of minion 1 (1-3, 0 if unused)
  input [1:0] my_health_2, // Health of minion 2 (1-3, 0 if unused)
  input [1:0] opp_health_1,// Opponent minion 1 health (1-3, 0 if unused)
  input [1:0] opp_health_2,// Opponent minion 2 health (1-3, 0 if unused)
  input [1:0] d,           // Damage units (1-3)
  output reg [31:0] prob,    // Probability result in Q16.16 format
  output reg done           // Computation complete flag
);

  // State machine states
  localparam S_IDLE = 2'b00;
  localparam S_READ = 2'b01;
  localparam S_DONE = 2'b10;
  
  reg [1:0] state;
  
  // ROM for probability values: 768 entries (256 health states * 3 d values)
  reg [31:0] rom [0:767];
  
  // Address calculation for ROM
  wire [7:0] health_state; // 8-bit representation of healths: {my_health_1, my_health_2, opp_health_1, opp_health_2}
  assign health_state = {my_health_1, my_health_2, opp_health_1, opp_health_2};
  
  wire [9:0] rom_addr; // 10-bit address for 768 entries
  assign rom_addr = health_state * 3 + (d - 1);
  
  // Initialize ROM with precomputed probabilities (values not included here for brevity)
  initial begin
    // This block should be replaced with actual precomputed values
    // for (int i = 0; i < 768; i++) rom[i] = 32'h00000000; // Placeholder
  end
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      prob <= 32'h00000000;
      done <= 1'b0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            state <= S_READ;
            done <= 1'b0;
          end
        end
        S_READ: begin
          prob <= rom[rom_addr]; // Read probability from ROM
          done <= 1'b1;
          state <= S_DONE;
        end
        S_DONE: begin
          if (!start) begin
            state <= S_IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule