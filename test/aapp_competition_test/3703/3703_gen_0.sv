module eurus_function(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [7:0] k,
  output reg [15:0] result,
  output reg done
);

  // State encoding
  localparam IDLE  = 2'b00;
  localparam RUN   = 2'b01;
  localparam DONE  = 2'b10;

  reg [1:0]  state, next_state;

  reg [15:0] current_value, next_current_value;
  reg [4:0]  steps_left, next_steps_left; // up to 16
  reg [3:0]  iter_cnt, next_iter_cnt;     // track cycles (max 16)
  wire [4:0] init_steps;

  // Compute m = min((k+1)/2, 16)
  assign init_steps = (((k + 8'd1) >> 1) > 5'd16) ? 5'd16 : ((k + 8'd1) >> 1);

  // ROM address and data
  reg  [15:0] rom_addr;
  wire [15:0] rom_data;

  // Simple synchronous state/regs update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      current_value <= 16'd0;
      steps_left    <= 5'd0;
      iter_cnt      <= 4'd0;
      result        <= 16'd0;
      done          <= 1'b0;
      rom_addr      <= 16'd0;
    end else begin
      state         <= next_state;
      current_value <= next_current_value;
      steps_left    <= next_steps_left;
      iter_cnt      <= next_iter_cnt;
      done          <= (next_state == DONE);
      if (next_state == DONE)
        result <= next_current_value;
      else if (!done && next_state == IDLE)
        result <= 16'd0;
      // ROM address is driven by current_value during RUN
      if (next_state == RUN)
        rom_addr <= current_value;
    end
  end

  // Next-state and datapath control
  always @* begin
    next_state         = state;
    next_current_value = current_value;
    next_steps_left    = steps_left;
    next_iter_cnt      = iter_cnt;

    case (state)
      IDLE: begin
        if (start && init_steps != 5'd0) begin
          next_current_value = n;
          next_steps_left    = init_steps;
          next_iter_cnt      = 4'd0;
          next_state         = RUN;
        end
      end

      RUN: begin
        // Termination conditions checked using current_value and counters
        if (current_value == 16'd1 || steps_left == 5'd0 || iter_cnt == 4'd15) begin
          next_state = DONE;
        end else begin
          // Consume one step and one cycle, update with ROM output
          next_current_value = rom_data;
          next_steps_left    = steps_left - 5'd1;
          next_iter_cnt      = iter_cnt + 4'd1;
          next_state         = RUN;
        end
      end

      DONE: begin
        // Hold result and done until start is deasserted, then go IDLE
        if (!start) begin
          next_state         = IDLE;
          next_current_value = 16'd0;
          next_steps_left    = 5'd0;
          next_iter_cnt      = 4'd0;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // 64KB ROM for Euler totient values Φ(x) for x in [0, 65535]
  // Synchronous read assumed for synthesis; initialized via $readmemh/array init.
  reg [15:0] phi_rom [0:65535];

  initial begin
    // Initialize with precomputed totient values, e.g.:
    // $readmemh("phi_rom_64k.hex", phi_rom);
  end

  assign rom_data = phi_rom[rom_addr];

endmodule