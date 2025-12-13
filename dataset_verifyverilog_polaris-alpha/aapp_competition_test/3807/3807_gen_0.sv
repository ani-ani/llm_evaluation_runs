module greedy_block_tower(
  input clk,
  input rst_n,
  input start,
  input [15:0] m,
  output reg [7:0] block_count,
  output reg [15:0] volume_X,
  output reg done
);

  // State encoding
  localparam [1:0]
    IDLE      = 2'b00,
    FIND_CUBE = 2'b01,
    UPDATE    = 2'b10;

  reg [1:0] state, next_state;

  reg [15:0] remaining_vol;
  reg [5:0]  candidate_a;         // 0..40
  reg [15:0] candidate_cube;      // a^3 via LUT
  reg [5:0]  best_a;              // best fit so far
  reg [15:0] best_cube;
  reg [5:0]  next_a;

  // Start edge detection
  reg start_d;
  wire start_rise = start & ~start_d;

  // Cube LUT function (combinational, only 0..40 used)
  function automatic [15:0] cube_lut(input [5:0] a);
    begin
      case (a)
        6'd0:  cube_lut = 16'd0;
        6'd1:  cube_lut = 16'd1;
        6'd2:  cube_lut = 16'd8;
        6'd3:  cube_lut = 16'd27;
        6'd4:  cube_lut = 16'd64;
        6'd5:  cube_lut = 16'd125;
        6'd6:  cube_lut = 16'd216;
        6'd7:  cube_lut = 16'd343;
        6'd8:  cube_lut = 16'd512;
        6'd9:  cube_lut = 16'd729;
        6'd10: cube_lut = 16'd1000;
        6'd11: cube_lut = 16'd1331;
        6'd12: cube_lut = 16'd1728;
        6'd13: cube_lut = 16'd2197;
        6'd14: cube_lut = 16'd2744;
        6'd15: cube_lut = 16'd3375;
        6'd16: cube_lut = 16'd4096;
        6'd17: cube_lut = 16'd4913;
        6'd18: cube_lut = 16'd5832;
        6'd19: cube_lut = 16'd6859;
        6'd20: cube_lut = 16'd8000;
        6'd21: cube_lut = 16'd9261;
        6'd22: cube_lut = 16'd10648;
        6'd23: cube_lut = 16'd12167;
        6'd24: cube_lut = 16'd13824;
        6'd25: cube_lut = 16'd15625;
        6'd26: cube_lut = 16'd17576;
        6'd27: cube_lut = 16'd19683;
        6'd28: cube_lut = 16'd21952;
        6'd29: cube_lut = 16'd24389;
        6'd30: cube_lut = 16'd27000;
        6'd31: cube_lut = 16'd29791;
        6'd32: cube_lut = 16'd32768;
        6'd33: cube_lut = 16'd35937;
        6'd34: cube_lut = 16'd39304;
        6'd35: cube_lut = 16'd42875;
        6'd36: cube_lut = 16'd46656;
        6'd37: cube_lut = 16'd50653;
        6'd38: cube_lut = 16'd54872;
        6'd39: cube_lut = 16'd59319;
        6'd40: cube_lut = 16'd64000;
        default: cube_lut = 16'd65535;
      endcase
    end
  endfunction

  // Sequential: state, registers, and control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      start_d       <= 1'b0;
      block_count   <= 8'd0;
      volume_X      <= 16'd0;
      remaining_vol <= 16'd0;
      done          <= 1'b0;
      candidate_a   <= 6'd0;
      candidate_cube<= 16'd0;
      best_a        <= 6'd0;
      best_cube     <= 16'd0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (!start) begin
            // Hold reset-like values while start is low
            block_count   <= 8'd0;
            volume_X      <= 16'd0;
            remaining_vol <= 16'd0;
          end
          if (start_rise) begin
            // Initialize for new computation
            block_count   <= 8'd0;
            volume_X      <= 16'd0;
            remaining_vol <= m;
            done          <= 1'b0;
            // Setup for FIND_CUBE
            candidate_a    <= 6'd40;
            candidate_cube <= cube_lut(6'd40);
            best_a         <= 6'd0;
            best_cube      <= 16'd0;
          end
        end

        FIND_CUBE: begin
          // Record best fit cube for current remaining_vol
          if (candidate_cube <= remaining_vol) begin
            best_a    <= candidate_a;
            best_cube <= candidate_cube;
          end

          // Prepare next candidate (successive approximation / linear search)
          if (candidate_a > 0) begin
            next_a          <= candidate_a - 6'd1;
            candidate_a     <= candidate_a - 6'd1;
            candidate_cube  <= cube_lut(candidate_a - 6'd1);
          end
        end

        UPDATE: begin
          if (best_cube != 16'd0 && best_cube <= remaining_vol && block_count < 8'd128) begin
            remaining_vol <= remaining_vol - best_cube;
            volume_X      <= volume_X + best_cube;
            block_count   <= block_count + 8'd1;
          end

          // If we're finishing, assert done; otherwise prepare next search
          if (remaining_vol == 16'd0 || best_cube == 16'd0 || block_count == 8'd128) begin
            done <= 1'b1;
          end else begin
            done <= 1'b0;
            // Re-init search for next block
            candidate_a    <= 6'd40;
            candidate_cube <= cube_lut(6'd40);
            best_a         <= 6'd0;
            best_cube      <= 16'd0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_rise)
          next_state = FIND_CUBE;
      end

      FIND_CUBE: begin
        // When candidate_a reaches 0, we have scanned all options
        if (candidate_a == 6'd0) begin
          next_state = UPDATE;
        end else begin
          next_state = FIND_CUBE;
        end
      end

      UPDATE: begin
        if (done) begin
          next_state = IDLE;
        end else begin
          next_state = FIND_CUBE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule