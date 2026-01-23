module fruit_slicer(
  input clk,
  input rst_n,
  input start,
  input [5:0] n,
  input [31:0] x [0:7],
  input [31:0] y [0:7],
  output reg [7:0] max_count,
  output reg done
);

  // State machine states
  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] COMPUTE_PROJECTIONS = 3'd1;
  localparam [2:0] SORT_EVENTS = 3'd2;
  localparam [2:0] SWEEP = 3'd3;
  localparam [2:0] UPDATE_MAX = 3'd4;
  localparam [2:0] NEXT_ANGLE = 3'd5;
  localparam [2:0] DONE_STATE = 3'd6;

  // Parameters
  localparam [3:0] ANGLE_STEPS = 4'd16;
  localparam [31:0] RADIUS_SCALED = 32'h00010000;

  // State registers
  reg [2:0] state;
  reg [4:0] angle_index;
  reg [4:0] circle_index;
  reg [31:0] cos_val, sin_val;
  reg [63:0] projection;
  reg [63:0] events [0:15];
  reg [4:0] event_count;
  reg [7:0] current_max;
  reg [7:0] overlap_count;

  // Precomputed cos/sin values for 16 angles in [0, π/2)
  wire [31:0] cos_table [0:15];
  wire [31:0] sin_table [0:15];
  assign cos_table[0] = 32'h00010000; // cos(0) = 1
  assign sin_table[0] = 32'h00000000; // sin(0) = 0
  assign cos_table[1] = 32'h0000EC83; // cos(π/32) ≈ 0.995184
  assign sin_table[1] = 32'h00003240; // sin(π/32) ≈ 0.195090
  assign cos_table[2] = 32'h0000D906; // cos(π/16) ≈ 0.980785
  assign sin_table[2] = 32'h00006487; // sin(π/16) ≈ 0.390181
  assign cos_table[3] = 32'h0000C58C; // cos(3π/32) ≈ 0.956940
  assign sin_table[3] = 32'h000096CB; // sin(3π/32) ≈ 0.587785
  assign cos_table[4] = 32'h0000B1F4; // cos(π/8) ≈ 0.923880
  assign sin_table[4] = 32'h0000C90F; // sin(π/8) ≈ 0.781831
  assign cos_table[5] = 32'h00009E3E; // cos(5π/32) ≈ 0.881921
  assign sin_table[5] = 32'h0000FB53; // sin(5π/32) ≈ 0.965926
  assign cos_table[6] = 32'h00008A67; // cos(3π/16) ≈ 0.831470
  assign sin_table[6] = 32'h00012D97; // sin(3π/16) ≈ 1.141040
  assign cos_table[7] = 32'h00007670; // cos(7π/32) ≈ 0.773010
  assign sin_table[7] = 32'h00015FD9; // sin(7π/32) ≈ 1.306563
  assign cos_table[8] = 32'h0000625A; // cos(π/4) ≈ 0.707107
  assign sin_table[8] = 32'h0001921F; // sin(π/4) ≈ 1.464466
  assign cos_table[9] = 32'h00004E25; // cos(9π/32) ≈ 0.634393
  assign sin_table[9] = 32'h0001C465; // sin(9π/32) ≈ 1.614126
  assign cos_table[10] = 32'h000039D1; // cos(5π/16) ≈ 0.555570
  assign sin_table[10] = 32'h0001F6A9; // sin(5π/16) ≈ 1.755732
  assign cos_table[11] = 32'h0000255E; // cos(11π/32) ≈ 0.471397
  assign sin_table[11] = 32'h000228EB; // sin(11π/32) ≈ 1.889922
  assign cos_table[12] = 32'h000010CC; // cos(3π/8) ≈ 0.382683
  assign sin_table[12] = 32'h00025B2C; // sin(3π/8) ≈ 2.017227
  assign cos_table[13] = 32'h00000000; // cos(13π/32) ≈ 0.290285
  assign sin_table[13] = 32'h00028D6B; // sin(13π/32) ≈ 2.138106
  assign cos_table[14] = 32'h00000000; // cos(7π/16) ≈ 0.195090
  assign sin_table[14] = 32'h0002BF9F; // sin(7π/16) ≈ 2.253040
  assign cos_table[15] = 32'h00000000; // cos(15π/32) ≈ 0.098017
  assign sin_table[15] = 32'h0002F1D1; // sin(15π/32) ≈ 2.362569

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_count <= 8'd0;
      done <= 1'b0;
      angle_index <= 5'd0;
      circle_index <= 5'd0;
      event_count <= 5'd0;
      current_max <= 8'd0;
      overlap_count <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && n > 0 && n <= 8) begin
            angle_index <= 5'd0;
            current_max <= 8'd0;
            state <= COMPUTE_PROJECTIONS;
            circle_index <= 5'd0;
          end
        end
        
        COMPUTE_PROJECTIONS: begin
          if (circle_index < n) begin
            cos_val <= cos_table[angle_index];
            sin_val <= sin_table[angle_index];
            projection <= ($signed(x[circle_index]) * $signed(cos_val)) + ($signed(y[circle_index]) * $signed(sin_val));
            events[2*circle_index] <= {32'h00000001, projection - RADIUS_SCALED};
            events[2*circle_index+1] <= {32'hFFFFFFFF, projection + RADIUS_SCALED};
            circle_index <= circle_index + 1;
          end else begin
            event_count <= n << 1;
            state <= SORT_EVENTS;
            circle_index <= 5'd0;
          end
        end
        
        SORT_EVENTS: begin
          // Bubble sort implementation
          reg [4:0] i, j;
          reg [63:0] temp;
          for (i = 0; i < event_count; i = i + 1) begin
            for (j = 0; j < event_count - i - 1; j = j + 1) begin
              if (events[j][31:0] > events[j+1][31:0]) begin
                temp <= events[j];
                events[j] <= events[j+1];
                events[j+1] <= temp;
              end
            end
          end
          state <= SWEEP;
          overlap_count <= 8'd0;
          circle_index <= 5'd0;
        end
        
        SWEEP: begin
          if (circle_index < event_count) begin
            if (events[circle_index][63:32] == 32'h00000001) begin
              overlap_count <= overlap_count + 1;
            end else begin
              overlap_count <= overlap_count - 1;
            end
            if (overlap_count > current_max) begin
              current_max <= overlap_count;
            end
            circle_index <= circle_index + 1;
          end else begin
            state <= UPDATE_MAX;
          end
        end
        
        UPDATE_MAX: begin
          if (current_max > max_count) begin
            max_count <= current_max;
          end
          state <= NEXT_ANGLE;
        end
        
        NEXT_ANGLE: begin
          if (angle_index < ANGLE_STEPS - 1) begin
            angle_index <= angle_index + 1;
            circle_index <= 5'd0;
            state <= COMPUTE_PROJECTIONS;
          end else begin
            state <= DONE_STATE;
          end
        end
        
        DONE_STATE: begin
          done <= 1'b1;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule