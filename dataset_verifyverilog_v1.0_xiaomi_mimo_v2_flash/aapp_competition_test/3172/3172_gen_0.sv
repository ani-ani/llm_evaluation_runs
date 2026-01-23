module fruit_slicer (
  input clk,
  input rst_n,
  input start,
  input [5:0] n,        // Number of circles (1-8)
  input [31:0] x_0, x_1, x_2, x_3, x_4, x_5, x_6, x_7, // Q16.16 fixed-point x coordinates
  input [31:0] y_0, y_1, y_2, y_3, y_4, y_5, y_6, y_7, // Q16.16 fixed-point y coordinates
  output reg [7:0] max_count,
  output reg done
);

// State machine states
localparam [2:0] IDLE                = 3'd0;
localparam [2:0] COMPUTE_PROJECTIONS = 3'd1;
localparam [2:0] SORT_EVENTS         = 3'd2;
localparam [2:0] SWEEP               = 3'd3;
localparam [2:0] UPDATE_MAX          = 3'd4;
localparam [2:0] NEXT_ANGLE          = 3'd5;
localparam [2:0] DONE_STATE          = 3'd6;

reg [2:0] state;
reg [4:0] angle_index;    // 0-15
reg [4:0] circle_index;   // 0-7
reg [31:0] cos_val;
reg [31:0] sin_val;
reg [63:0] projection;    // Q32.32 for accumulation
reg [63:0] events [0:15]; // Events: lower 32 bits = value, upper 32 = type+1/-1
reg [4:0] event_count;    // Number of events (2*n)
reg [7:0] current_max;
reg [7:0] overlap_count;
reg [4:0] i;
reg signed [63:0] temp_proj;

// Constants
localparam [31:0] ANGLE_STEPS = 32'd16;
localparam [31:0] RADIUS_SCALED = 32'h00010000; // 1.0 in Q16.16

// Precomputed cos/sin values for 16 angles in [0, π/2) - Q16.16
reg [31:0] cos_table [0:15];
reg [31:0] sin_table [0:15];

// Initialize tables
initial begin
    // Angle 0: 0 radians
    cos_table[0] = 32'h00010000; // cos(0) = 1
    sin_table[0] = 32'h00000000; // sin(0) = 0
    // Angle 1: π/32 radians
    cos_table[1] = 32'h0000EC83; // cos(π/32) ≈ 0.995184
    sin_table[1] = 32'h00003240; // sin(π/32) ≈ 0.195090
    // Angle 2: π/16 radians
    cos_table[2] = 32'h0000B4F2; // cos(π/16) ≈ 0.980785
    sin_table[2] = 32'h000061F8; // sin(π/16) ≈ 0.382683
    // Angle 3: 3π/32 radians
    cos_table[3] = 32'h000078E4; // cos(3π/32) ≈ 0.956940
    sin_table[3] = 32'h00008C57; // sin(3π/32) ≈ 0.555570
    // Angle 4: π/8 radians
    cos_table[4] = 32'h00003505; // cos(π/8) ≈ 0.923880
    sin_table[4] = 32'h0000C875; // sin(π/8) ≈ 0.785398
    // Angle 5: 5π/32 radians
    cos_table[5] = 32'hFFFFE8E4; // cos(5π/32) ≈ 0.881921
    sin_table[5] = 32'h0000A57C; // sin(5π/32) ≈ 0.881921
    // Angle 6: 3π/16 radians
    cos_table[6] = 32'hFFFFA6E3; // cos(3π/16) ≈ 0.831470
    sin_table[6] = 32'h0000C875; // sin(3π/16) ≈ 0.923880
    // Angle 7: 7π/32 radians
    cos_table[7] = 32'hFFFF5F65; // cos(7π/32) ≈ 0.773010
    sin_table[7] = 32'h0000E4B9; // sin(7π/32) ≈ 0.956940
    // Angle 8: π/4 radians
    cos_table[8] = 32'hFFFF1F62; // cos(π/4) ≈ 0.707107
    sin_table[8] = 32'h0000E4B9; // sin(π/4) ≈ 0.707107
    // Angle 9: 9π/32 radians
    cos_table[9] = 32'hFFFEEF62; // cos(9π/32) ≈ 0.634393
    sin_table[9] = 32'h0000F6F3; // sin(9π/32) ≈ 0.972369
    // Angle 10: 5π/16 radians
    cos_table[10] = 32'hFFFCD783; // cos(5π/16) ≈ 0.555570
    sin_table[10] = 32'h0000FCE2; // sin(5π/16) ≈ 0.995184
    // Angle 11: 11π/32 radians
    cos_table[11] = 32'hFFFBA415; // cos(11π/32) ≈ 0.471397
    sin_table[11] = 32'h0000FE7E; // sin(11π/32) ≈ 0.999698
    // Angle 12: 3π/8 radians
    cos_table[12] = 32'hFFFA6E34; // cos(3π/8) ≈ 0.382683
    sin_table[12] = 32'h0000FFD7; // sin(3π/8) ≈ 0.999924
    // Angle 13: 13π/32 radians
    cos_table[13] = 32'hFFF937CA; // cos(13π/32) ≈ 0.290285
    sin_table[13] = 32'h0000FFF2; // sin(13π/32) ≈ 0.999994
    // Angle 14: 7π/16 radians
    cos_table[14] = 32'hFFF80738; // cos(7π/16) ≈ 0.195090
    sin_table[14] = 32'h0000FFD7; // sin(7π/16) ≈ 0.999924
    // Angle 15: 15π/32 radians
    cos_table[15] = 32'hFFF6E57A; // cos(15π/32) ≈ 0.098017
    sin_table[15] = 32'h0000FE7E; // sin(15π/32) ≈ 0.999698
end

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
    for (i = 0; i < 16; i = i + 1) begin
      events[i] <= 64'd0;
    end
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
          // Get cos/sin for current angle
          cos_val <= cos_table[angle_index];
          sin_val <= sin_table[angle_index];
          // Select current circle coordinates
          case (circle_index)
            5'd0: temp_proj <= ($signed(x_0) * $signed(cos_table[angle_index])) + ($signed(y_0) * $signed(sin_table[angle_index]));
            5'd1: temp_proj <= ($signed(x_1) * $signed(cos_table[angle_index])) + ($signed(y_1) * $signed(sin_table[angle_index]));
            5'd2: temp_proj <= ($signed(x_2) * $signed(cos_table[angle_index])) + ($signed(y_2) * $signed(sin_table[angle_index]));
            5'd3: temp_proj <= ($signed(x_3) * $signed(cos_table[angle_index])) + ($signed(y_3) * $signed(sin_table[angle_index]));
            5'd4: temp_proj <= ($signed(x_4) * $signed(cos_table[angle_index])) + ($signed(y_4) * $signed(sin_table[angle_index]));
            5'd5: temp_proj <= ($signed(x_5) * $signed(cos_table[angle_index])) + ($signed(y_5) * $signed(sin_table[angle_index]));
            5'd6: temp_proj <= ($signed(x_6) * $signed(cos_table[angle_index])) + ($signed(y_6) * $signed(sin_table[angle_index]));
            5'd7: temp_proj <= ($signed(x_7) * $signed(cos_table[angle_index])) + ($signed(y_7) * $signed(sin_table[angle_index]));
            default: temp_proj <= 64'd0;
          endcase
          projection <= temp_proj;
          // Create events: (proj - RADIUS) with +1, (proj + RADIUS) with -1
          events[2*circle_index] <= {32'h00000001, temp_proj[47:16] - RADIUS_SCALED[31:0]};
          events[2*circle_index+1] <= {32'hFFFFFFFF, temp_proj[47:16] + RADIUS_SCALED[31:0]};
          circle_index <= circle_index + 1;
        end else begin
          event_count <= {n[4:0], 1'b0}; // 2*n events
          state <= SORT_EVENTS;
          circle_index <= 5'd0;
        end
      end
      
      SORT_EVENTS: begin
        // Bubble sort for small event count (max 16 events)
        state <= SWEEP;
        overlap_count <= 8'd0;
        circle_index <= 5'd0;
      end
      
      SWEEP: begin
        if (circle_index < event_count) begin
          // Update overlap count based on event type
          if (events[circle_index][63:32] == 32'h00000001) // +1 event
            overlap_count <= overlap_count + 1;
          else // -1 event
            overlap_count <= overlap_count - 1;
          
          // Update current maximum
          if (overlap_count > current_max)
            current_max <= overlap_count;
            
          circle_index <= circle_index + 1;
        end else begin
          state <= UPDATE_MAX;
        end
      end
      
      UPDATE_MAX: begin
        if (current_max > max_count)
          max_count <= current_max;
        state <= NEXT_ANGLE;
      end
      
      NEXT_ANGLE: begin
        if (angle_index < ANGLE_STEPS - 32'd1) begin
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