module minimum_energy_search(
  input clk,
  input rst_n,
  input start,
  input [31:0] p_target, // Q12.20 fixed-point (P * 2^20)
  input [7:0] [9:0] energies, // 8 boxes, 10-bit energy values each
  input [7:0] [31:0] probs, // 8 boxes, Q12.20 probabilities each
  output reg [12:0] min_energy, // Max energy 8*1000=8000 (13-bit)
  output reg done
);

  // FSM states
  localparam IDLE  = 2'b00;
  localparam RUN   = 2'b01;
  localparam FINAL = 2'b10;

  reg [1:0] state, next_state;

  // 8-bit subset index (0..255)
  reg [7:0] subset_cnt;

  // Combinational signals for current subset
  reg [12:0] subset_energy;
  reg [31:0] subset_prob;

  // Control for initializing and counting cycles
  wire last_cycle = (subset_cnt == 8'hFF);

  // Combinational calculation of subset energy and probability for current subset_cnt
  always @* begin
    subset_energy = 13'd0;
    subset_prob   = 32'd0;

    // Box 0
    if (subset_cnt[0]) begin
      subset_energy = subset_energy + energies[0];
      subset_prob   = subset_prob   + probs[0];
    end
    // Box 1
    if (subset_cnt[1]) begin
      subset_energy = subset_energy + energies[1];
      subset_prob   = subset_prob   + probs[1];
    end
    // Box 2
    if (subset_cnt[2]) begin
      subset_energy = subset_energy + energies[2];
      subset_prob   = subset_prob   + probs[2];
    end
    // Box 3
    if (subset_cnt[3]) begin
      subset_energy = subset_energy + energies[3];
      subset_prob   = subset_prob   + probs[3];
    end
    // Box 4
    if (subset_cnt[4]) begin
      subset_energy = subset_energy + energies[4];
      subset_prob   = subset_prob   + probs[4];
    end
    // Box 5
    if (subset_cnt[5]) begin
      subset_energy = subset_energy + energies[5];
      subset_prob   = subset_prob   + probs[5];
    end
    // Box 6
    if (subset_cnt[6]) begin
      subset_energy = subset_energy + energies[6];
      subset_prob   = subset_prob   + probs[6];
    end
    // Box 7
    if (subset_cnt[7]) begin
      subset_energy = subset_energy + energies[7];
      subset_prob   = subset_prob   + probs[7];
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = RUN;
        end
      end
      RUN: begin
        if (last_cycle) begin
          next_state = FINAL;
        end
      end
      FINAL: begin
        if (start) begin
          next_state = RUN;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential state, counters, and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      subset_cnt  <= 8'd0;
      min_energy  <= 13'd8191; // initialize to max
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            subset_cnt <= 8'd0;
            min_energy <= 13'd8191;
          end
        end

        RUN: begin
          // Evaluate current subset (subset_cnt)
          if ((subset_prob >= p_target) && (subset_energy < min_energy)) begin
            min_energy <= subset_energy;
          end

          // Increment subset counter each cycle
          subset_cnt <= subset_cnt + 8'd1;
        end

        FINAL: begin
          // Hold result, assert done
          done <= 1'b1;
          // On a new start, re-init in next_state (RUN) via IDLE-like behavior
          if (start) begin
            subset_cnt <= 8'd0;
            min_energy <= 13'd8191;
            done       <= 1'b0;
          end
        end

        default: begin
          done       <= 1'b0;
          subset_cnt <= 8'd0;
          min_energy <= 13'd8191;
        end
      endcase
    end
  end

endmodule