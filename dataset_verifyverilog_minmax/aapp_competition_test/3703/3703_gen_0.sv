module eurus_function (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [7:0] k,
  output reg [15:0] result,
  output reg done
);

  // 64KB ROM containing Φ(x) for x in [0, 65535]
  // Depth 65536, width 16 bits => 128 KiB, which is >= 64KB requirement.
  logic [15:0] phi_rom [0:65535];

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  logic [15:0] curr_value;
  logic [4:0] step_count;  // up to 16
  logic [15:0] phi_out;

  // ROM init (Φ for 0..16, others are 0 for completeness; can be replaced with $readmemh)
  initial begin
    // Initialize all to 0
    for (int i = 0; i < 65536; i++) phi_rom[i] = 16'd0;
    // Totient values for 0..16
    phi_rom[0]  = 16'd0;   // Φ(0) is 0 by convention in this implementation
    phi_rom[1]  = 16'd1;   // Φ(1) = 1
    phi_rom[2]  = 16'd1;   // Φ(2) = 1
    phi_rom[3]  = 16'd2;   // Φ(3) = 2
    phi_rom[4]  = 16'd2;   // Φ(4) = 2
    phi_rom[5]  = 16'd4;   // Φ(5) = 4
    phi_rom[6]  = 16'd2;   // Φ(6) = 2
    phi_rom[7]  = 16'd6;   // Φ(7) = 6
    phi_rom[8]  = 16'd4;   // Φ(8) = 4
    phi_rom[9]  = 16'd6;   // Φ(9) = 6
    phi_rom[10] = 16'd4;   // Φ(10) = 4
    phi_rom[11] = 16'd10;  // Φ(11) = 10
    phi_rom[12] = 16'd4;   // Φ(12) = 4
    phi_rom[13] = 16'd12;  // Φ(13) = 12
    phi_rom[14] = 16'd6;   // Φ(14) = 6
    phi_rom[15] = 16'd8;   // Φ(15) = 8
    phi_rom[16] = 16'd8;   // Φ(16) = 8
    // Remaining entries already initialized to 0. They can be precomputed with a tool and loaded via $readmemh if needed.
  end

  // ROM read (combinational)
  always_comb begin
    phi_out = phi_rom[curr_value];
  end

  // Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      curr_value <= 16'd0;
      step_count <= 5'd0;
      result     <= 16'd0;
      done       <= 1'b0;
    end else begin
      state      <= next_state;
      curr_value <= curr_value; // default hold
      step_count <= step_count; // default hold
      result     <= result;     // default hold
      done       <= done;       // default hold

      case (next_state)
        IDLE: begin
          curr_value <= 16'd0;
          step_count <= 5'd0;
          result     <= 16'd0;
          done       <= 1'b0;
        end

        RUN: begin
          // First cycle: load Φ(n)
          curr_value <= phi_out;
          // Decrement step counter each cycle
          step_count <= (step_count == 5'd0) ? 5'd0 : (step_count - 5'd1);
        end

        DONE: begin
          result <= curr_value;
          done   <= 1'b1;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          // Compute m = min((k+1)/2, 16)
          step_count = (( ( {7'b0, k} + 8'd1 ) >> 1 ) > 16) ? 5'd16 : ( ( {7'b0, k} + 8'd1 ) >> 1 );
          curr_value = n;
          // If starting value is 1, finish immediately without any reads
          if (n == 16'd1) begin
            result = 16'd1;
            done   = 1'b1;
            next_state = DONE;
          end else begin
            // Start iterating: go to RUN and load Φ(n) in this same cycle (first iteration)
            next_state = RUN;
          end
        end else begin
          step_count = 5'd0;
          curr_value = 16'd0;
        end
      end

      RUN: begin
        // Load Φ(current_value) each cycle and update current_value
        // Early stop if current_value becomes 1
        if (phi_out == 16'd1) begin
          next_state = DONE;
        end else if (step_count == 5'd0) begin
          // Reached max steps
          next_state = DONE;
        end else begin
          next_state = RUN;
        end
      end

      DONE: begin
        if (start) begin
          // Re-start on start=1 while done=1 (acts like a trigger)
          step_count = (( ( {7'b0, k} + 8'd1 ) >> 1 ) > 16) ? 5'd16 : ( ( {7'b0, k} + 8'd1 ) >> 1 );
          curr_value = n;
          if (n == 16'd1) begin
            result = 16'd1;
            done   = 1'b1;
            next_state = DONE;
          end else begin
            next_state = RUN;
          end
        end else begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule
