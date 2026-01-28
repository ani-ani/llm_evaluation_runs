module pile_counter(
  input clk, rst_n, start,
  input [3:0] n,
  input [5:0] a0, a1, a2, a3, a4, a5, a6, a7,
  output reg [29:0] result,
  output reg done
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] PRECOMP = 4'd1;
localparam [3:0] INIT = 4'd2;
localparam [3:0] LOOP_S = 4'd3;
localparam [3:0] NEXT_MASK = 4'd4;
localparam [3:0] LOOP_K = 4'd5;
localparam [3:0] CHECK = 4'd6;
localparam [3:0] UPDATE = 4'd7;
localparam [3:0] FINISH = 4'd8;

reg [3:0] state;

// Memories for DP
reg signed [4:0] dp_max [0:255];
reg [29:0] dp_count [0:255];

// Control registers
reg [3:0] s, k;
reg [7:0] mask;
reg [4:0] candidate;

// Helper function for popcount
function [3:0] popcount;
  input [7:0] v;
  begin
    popcount = v[0] + v[1] + v[2] + v[3] + v[4] + v[5] + v[6] + v[7];
  end
endfunction

// Precomputed signals
reg [7:0] divisors [0:7];
reg [7:0] div_set [0:7];

integer i;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    result <= 30'd0;
    
    // Initialize DP arrays
    for (i = 0; i < 256; i = i + 1) begin
      dp_max[i] <= 5'd0;
      dp_count[i] <= 30'd0;
    end
    
    // Initialize control registers
    s <= 4'd0;
    k <= 4'd0;
    mask <= 8'd0;
    candidate <= 5'd0;
    
    // Initialize divisors and div_set
    for (i = 0; i < 8; i = i + 1) begin
      divisors[i] <= 8'd0;
      div_set[i] <= 8'd0;
    end
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          state <= PRECOMP;
        end
      end
      
      PRECOMP: begin
        // Compute divisors and div_set
        for (i = 0; i < 8; i = i + 1) begin
          divisors[i] <= 8'd0;
          div_set[i] <= 8'd0;
        end
        state <= INIT;
      end
      
      INIT: begin
        dp_max[0] <= 5'd0;
        dp_count[0] <= 30'd1;
        s <= 4'd1;
        state <= LOOP_S;
      end
      
      LOOP_S: begin
        if (s > n) begin
          state <= FINISH;
        end else begin
          mask <= 8'd0;
          state <= NEXT_MASK;
        end
      end
      
      NEXT_MASK: begin
        if (mask == 8'd255) begin
          s <= s + 4'd1;
          state <= LOOP_S;
        end else if (popcount(mask) == s) begin
          dp_max[mask] <= 5'd0;
          dp_count[mask] <= 30'd0;
          k <= 4'd0;
          state <= LOOP_K;
        end else begin
          mask <= mask + 8'd1;
        end
      end
      
      LOOP_K: begin
        if (k >= 8) begin
          state <= NEXT_MASK;
        end else if (mask[k]) begin
          state <= CHECK;
        end else begin
          k <= k + 4'd1;
        end
      end
      
      CHECK: begin
        // Condition: exists divisor i with popcount(mask & div_set[i]) >= 3
        reg condition_met;
        condition_met = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
          if (popcount(mask & div_set[i]) >= 3) begin
            condition_met = 1'b1;
          end
        end
        
        if (condition_met) begin
          candidate <= dp_max[mask & ~(1 << k)] + 5'd1;
          state <= UPDATE;
        end else begin
          k <= k + 4'd1;
          state <= LOOP_K;
        end
      end
      
      UPDATE: begin
        if (candidate > dp_max[mask]) begin
          dp_max[mask] <= candidate;
          dp_count[mask] <= dp_count[mask & ~(1 << k)];
        end else if (candidate == dp_max[mask]) begin
          dp_count[mask] <= (dp_count[mask] + dp_count[mask & ~(1 << k)]) % 30'd1000000007;
        end
        k <= k + 4'd1;
        state <= LOOP_K;
      end
      
      FINISH: begin
        result <= dp_count[(1 << n) - 1];
        done <= 1'b1;
        state <= IDLE;
      end
      
      default: state <= IDLE;
    endcase
  end
end

endmodule