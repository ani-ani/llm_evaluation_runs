module elisabeth_path (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] D,  // Q16.16 fixed-point
    output reg [31:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] INIT = 3'b001;
localparam [2:0] LOAD = 3'b010;
localparam [2:0] CHECK = 3'b011;
localparam [2:0] INCREMENT = 3'b100;
localparam [2:0] OUTPUT = 3'b101;

reg [2:0] state;
reg [2:0] next_state;
reg [31:0] min_angle;
reg [31:0] path_index;
reg [31:0] current_distance;
reg [31:0] current_angle;

// Precomputed paths for graph with 5 junctions
// Path 0: [1,3,5] - distance: 447.2136, angle: 126.86989765
// Path 1: [1,2,3,5] - distance: 465.0282, angle: 108.4349
// Path 2: [1,3,4,5] - distance: 465.0282, angle: 108.4349
// Path 3: [1,2,3,4,5] - distance: 482.8428, angle: 90.0

localparam [31:0] dist0 = 32'd29300000; // 447.2136 * 65536
localparam [31:0] dist1 = 32'd30470000; // 465.0282 * 65536
localparam [31:0] dist2 = 32'd30470000; // 465.0282 * 65536
localparam [31:0] dist3 = 32'd31640000; // 482.8428 * 65536

localparam [31:0] angle0 = 32'd8315000; // 126.86989765 * 65536
localparam [31:0] angle1 = 32'd7100000; // 108.4349 * 65536
localparam [31:0] angle2 = 32'd7100000; // 108.4349 * 65536
localparam [31:0] angle3 = 32'd5898240; // 90.0 * 65536

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: next_state = start ? INIT : IDLE;
        INIT: next_state = LOAD;
        LOAD: next_state = CHECK;
        CHECK: next_state = INCREMENT;
        INCREMENT: next_state = (path_index < 4) ? LOAD : OUTPUT;
        OUTPUT: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        min_angle <= 32'h7FFFFFFF;
        path_index <= 32'd0;
        current_distance <= 32'd0;
        current_angle <= 32'd0;
        result <= 32'd0;
        done <= 1'b0;
    end else begin
        case (state)
            INIT: begin
                min_angle <= 32'h7FFFFFFF;
                path_index <= 32'd0;
                done <= 1'b0;
            end
            LOAD: begin
                case (path_index)
                    32'd0: begin current_distance <= dist0; current_angle <= angle0; end
                    32'd1: begin current_distance <= dist1; current_angle <= angle1; end
                    32'd2: begin current_distance <= dist2; current_angle <= angle2; end
                    32'd3: begin current_distance <= dist3; current_angle <= angle3; end
                    default: begin current_distance <= 32'd0; current_angle <= 32'd0; end
                endcase
            end
            CHECK: begin
                if (current_distance <= D && current_angle < min_angle)
                    min_angle <= current_angle;
            end
            INCREMENT: path_index <= path_index + 32'd1;
            OUTPUT: begin
                if (min_angle == 32'h7FFFFFFF) result <= 32'hFFFFFFFF;
                else result <= min_angle;
                done <= 1'b1;
            end
            IDLE: done <= 1'b0;
            default: begin
                min_angle <= min_angle;
                path_index <= path_index;
                current_distance <= current_distance;
                current_angle <= current_angle;
                result <= result;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule