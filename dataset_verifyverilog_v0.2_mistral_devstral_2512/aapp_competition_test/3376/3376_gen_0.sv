module nudgemon_optimal_xp (
  input clk,
  input rst_n,
  input start,
  input [5:0] num_catches,
  input [5:0] num_families,
  input [31:0] catch_times [0:7],
  input [7:0] catch_family [0:7],
  input [3:0] family_evolution_cost [0:7],
  input [3:0] family_chain_length [0:7],
  output reg [31:0] max_xp,
  output reg done
);

  // Constants in Q16.16 format
  localparam [31:0] XP_100 = 32'h00640000;
  localparam [31:0] XP_200 = 32'h00C80000;
  localparam [31:0] XP_500 = 32'h01F40000;
  localparam [31:0] XP_1000 = 32'h03E80000;
  localparam [31:0] WINDOW_DURATION = 32'h07080000;

  // State machine
  typedef enum logic [3:0] {
    IDLE,
    PARSE_INPUT,
    EVALUATE_WINDOWS,
    COMPUTE_XP,
    DONE
  } state_t;
  state_t state, next_state;

  // Counters and registers
  reg [5:0] catch_idx;
  reg [5:0] family_idx;
  reg [5:0] window_idx;
  reg [5:0] cycle_count;

  // Family data storage (ROM-style)
  reg [3:0] family_cost [0:7];
  reg [3:0] family_chain [0:7];

  // Catch data storage (32-bit time + 8-bit family)
  reg [39:0] catch_data [0:7];

  // Candidate window start times
  reg [31:0] window_start [0:3];

  // XP calculation registers
  reg [31:0] window_xp [0:3];
  reg [31:0] current_max_xp;

  // Temporary calculation registers
  reg [31:0] temp_xp_catches;
  reg [31:0] temp_xp_evolutions;
  reg [31:0] temp_total_xp;
  reg [31:0] temp_candies;
  reg [31:0] temp_evolutions;
  reg [31:0] temp_cost;
  reg [31:0] temp_count;

  // State machine transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_xp <= 32'h00000000;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PARSE_INPUT;
      end
      PARSE_INPUT: begin
        if (cycle_count == 6'd7) next_state = EVALUATE_WINDOWS;
      end
      EVALUATE_WINDOWS: begin
        if (window_idx == 6'd3) next_state = COMPUTE_XP;
      end
      COMPUTE_XP: begin
        if (window_idx == 6'd3) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // State machine actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      catch_idx <= 6'd0;
      family_idx <= 6'd0;
      window_idx <= 6'd0;
      cycle_count <= 6'd0;
      current_max_xp <= 32'h00000000;
      
      // Reset family data
      for (int i = 0; i < 8; i++) begin
        family_cost[i] <= 4'd0;
        family_chain[i] <= 4'd0;
      end
      
      // Reset catch data
      for (int i = 0; i < 8; i++) begin
        catch_data[i] <= 40'd0;
      end
      
      // Reset window data
      for (int i = 0; i < 4; i++) begin
        window_start[i] <= 32'd0;
        window_xp[i] <= 32'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          max_xp <= 32'h00000000;
        end
        
        PARSE_INPUT: begin
          if (cycle_count < 6'd8) begin
            if (cycle_count < 6'd8) begin
              // Store family data
              if (family_idx < num_families) begin
                family_cost[family_idx] <= family_evolution_cost[family_idx];
                family_chain[family_idx] <= family_chain_length[family_idx];
                family_idx <= family_idx + 1'b1;
              end
              // Store catch data
              if (catch_idx < num_catches) begin
                catch_data[catch_idx] <= {catch_times[catch_idx], catch_family[catch_idx]};
                catch_idx <= catch_idx + 1'b1;
              end
            end
            cycle_count <= cycle_count + 1'b1;
          end
        end
        
        EVALUATE_WINDOWS: begin
          if (window_idx < 6'd4) begin
            // Calculate window start times
            case (window_idx)
              6'd0: window_start[0] <= catch_times[0];
              6'd1: window_start[1] <= catch_times[num_catches / 4];
              6'd2: window_start[2] <= catch_times[num_catches / 2];
              6'd3: window_start[3] <= catch_times[3 * num_catches / 4];
            endcase
            window_idx <= window_idx + 1'b1;
          end
        end
        
        COMPUTE_XP: begin
          if (window_idx < 6'd4) begin
            // Reset temporary registers
            temp_count <= 32'd0;
            temp_candies <= 32'd0;
            temp_xp_catches <= 32'd0;
            temp_xp_evolutions <= 32'd0;
            
            // Count catches in window
            for (int i = 0; i < num_catches; i++) begin
              if (catch_times[i] >= window_start[window_idx] && 
                  catch_times[i] < window_start[window_idx] + WINDOW_DURATION) begin
                temp_count <= temp_count + 32'd1;
              end
            end
            
            // Calculate XP from catches (200 * count)
            temp_xp_catches <= temp_count * XP_200;
            
            // Calculate candies (3 * count)
            temp_candies <= temp_count * 32'd3;
            
            // Calculate maximum evolutions
            if (num_families > 0) begin
              temp_cost <= family_cost[0]; // Use first family's cost
              if (temp_cost > 0) begin
                temp_evolutions <= temp_candies / temp_cost;
              end else begin
                temp_evolutions <= 32'd0;
              end
            end else begin
              temp_evolutions <= 32'd0;
            end
            
            // Calculate XP from evolutions (1000 * evolutions)
            temp_xp_evolutions <= temp_evolutions * XP_1000;
            
            // Total XP for this window
            temp_total_xp <= temp_xp_catches + temp_xp_evolutions;
            window_xp[window_idx] <= temp_total_xp;
            
            // Update maximum XP
            if (temp_total_xp > current_max_xp) begin
              current_max_xp <= temp_total_xp;
            end
            
            window_idx <= window_idx + 1'b1;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          max_xp <= current_max_xp;
        end
      endcase
    end
  end

endmodule