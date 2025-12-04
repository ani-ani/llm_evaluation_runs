module truck_encounter_counter(input clk, input rst_n, input start, input [3:0] truck1_segments, input [3:0] truck2_segments, input [9:0] truck1_route [0:3], input [9:0] truck2_route [0:3], output reg [7:0] encounter_count, output reg done);
  typedef enum logic [1:0] {IDLE, VALIDATE, SIMULATE, COMPLETE} state_t;
  state_t state, next_state;
  reg [11:0] time_counter;
  reg valid1, valid2;
  reg [1:0] truck1_seg_idx, truck2_seg_idx;
  reg [11:0] truck1_pos, truck2_pos;
  reg truck1_active, truck2_active;
  
  always_comb begin : validate_truck1
    if (truck1_segments < 4'd2 || truck1_segments > 4'd3) begin
      valid1 = 0;
    end else begin
      case (truck1_segments)
        4'd2: valid1 = ((truck1_route[1] > truck1_route[0]) ^ (truck1_route[2] > truck1_route[1])) != 0;
        4'd3: valid1 = ((truck1_route[1] > truck1_route[0]) != (truck1_route[2] > truck1_route[1])) &&
                      ((truck1_route[2] > truck1_route[1]) != (truck1_route[3] > truck1_route[2]));
        default: valid1 = 0;
      endcase
    end
  end

  always_comb begin : validate_truck2
    if (truck2_segments < 4'd2 || truck2_segments > 4'd3) begin
      valid2 = 0;
    end else begin
      case (truck2_segments)
        4'd2: valid2 = ((truck2_route[1] > truck2_route[0]) ^ (truck2_route[2] > truck2_route[1])) != 0;
        4'd3: valid2 = ((truck2_route[1] > truck2_route[0]) != (truck2_route[2] > truck2_route[1])) &&
                      ((truck2_route[2] > truck2_route[1]) != (truck2_route[3] > truck2_route[2]));
        default: valid2 = 0;
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      encounter_count <= 0;
      done <= 0;
      time_counter <= 0;
      truck1_seg_idx <= 0;
      truck2_seg_idx <= 0;
      truck1_pos <= 0;
      truck2_pos <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) state <= VALIDATE;
        end
        
        VALIDATE: begin
          if (valid1 && valid2) begin
            state <= SIMULATE;
            truck1_seg_idx <= 0;
            truck2_seg_idx <= 0;
            truck1_pos <= {truck1_route[0], 2'b00};
            truck2_pos <= {truck2_route[0], 2'b00};
            time_counter <= 0;
            encounter_count <= 0;
          end else begin
            state <= COMPLETE;
            done <= 1;
            encounter_count <= 0;
          end
        end
        
        SIMULATE: begin
          if (time_counter < 4096 && (truck1_seg_idx < truck1_segments-1 || truck2_seg_idx < truck2_segments-1)) begin
            time_counter <= time_counter + 1;
            
            // Truck1 movement
            if (truck1_seg_idx < truck1_segments-1) begin
              reg signed [12:0] step_dir;
              reg [11:0] end_pos = {truck1_route[truck1_seg_idx+1], 2'b00};
              step_dir = (truck1_route[truck1_seg_idx+1] > truck1_route[truck1_seg_idx]) ? 1 : -1;
              if ((step_dir == 1 && (truck1_pos + 1) >= end_pos) || (step_dir == -1 && (truck1_pos - 1) <= end_pos)) begin
                truck1_pos <= end_pos;
                truck1_seg_idx <= truck1_seg_idx + 1;
              end else begin
                truck1_pos <= truck1_pos + step_dir;
              end
            end
            
            // Truck2 movement
            if (truck2_seg_idx < truck2_segments-1) begin
              reg signed [12:0] step_dir;
              reg [11:0] end_pos = {truck2_route[truck2_seg_idx+1], 2'b00};
              step_dir = (truck2_route[truck2_seg_idx+1] > truck2_route[truck2_seg_idx]) ? 1 : -1;
              if ((step_dir == 1 && (truck2_pos + 1) >= end_pos) || (step_dir == -1 && (truck2_pos - 1) <= end_pos)) begin
                truck2_pos <= end_pos;
                truck2_seg_idx <= truck2_seg_idx + 1;
              end else begin
                truck2_pos <= truck2_pos + step_dir;
              end
            end
            
            if (truck1_pos == truck2_pos && truck1_pos[1:0] != 0) encounter_count <= encounter_count + 1;
          end else begin
            state <= COMPLETE;
            done <= 1;
          end
        end
        
        COMPLETE: done <= 1;
      endcase
    end
  end

  always_comb begin
    next_state = state;
    if (state == COMPLETE && start) next_state = VALIDATE;
  end
endmodule