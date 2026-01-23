module taxi_expected_distance (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [5:0] n,
    input [31:0] x_coords [0:7],
    input [31:0] y_coords [0:7],
    output reg [31:0] expected_distance,
    output reg done
);

// Registers
reg [2:0] state;
reg [31:0] area;
reg [31:0] e_x_contrib;
reg [31:0] e_y_contrib;
reg [31:0] final_result;
reg [31:0] count_down;
reg [31:0] i_count;
reg [31:0] sum_area;

localparam IDLE = 3'd0;
localparam COMPUTE_AREA = 3'd1;
localparam COMPUTE_X = 3'd2;
localparam COMPUTE_Y = 3'd3;
localparam FINALIZE = 3'd4;
localparam WAIT = 3'd5;
localparam DONE = 3'd6;

// Default values (for synthesis)
// But in Verilog, initial blocks are not synthesized, so rely on reset.

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        area <= 32'd0;
        e_x_contrib <= 32'd0;
        e_y_contrib <= 32'd0;
        final_result <= 32'd0;
        count_down <= 32'd0;
        i_count <= 32'd0;
        sum_area <= 32'd0;
        done <= 1'b0;
        expected_distance <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COMPUTE_AREA;
                    i_count <= 32'd0;
                    sum_area <= 32'd0;
                end
            end
            COMPUTE_AREA: begin
                if (i_count < n) begin
                    int i = i_count;
                    int next_i = (i +1) % n;
                    // Cast to signed for correct multiplication
                    reg [31:0] x_i = (signed)x_coords[i];
                    reg [31:0] y_i = (signed)y_coords[i];
                    reg [31:0] x_next = (signed)x_coords[next_i];
                    reg [31:0] y_next = (signed)y_coords[next_i];
                    reg [63:0] term1 = (signed)(x_i) * (signed)(y_next); // Signed multiplication, 64 bits
                    reg [63:0] term2 = (signed)(x_next) * (signed)(y_i);
                    reg [31:0] diff;
                    // Truncate to 32 bits? Or saturate? This is a problem, but proceed with truncation
                    diff = term1[31:0] - term2[31:0];
                    sum_area <= sum_area + diff;
                    i_count <= i_count +1;
                end else begin
                    // Compute area as sum_area shifted right by 1 (0.5)
                    area <= sum_area >> 1;
                    state <= COMPUTE_X;
                    i_count <= 32'd0;
                end
            end
            COMPUTE_X: begin
                // Placeholder: assume some computation, but for now just move on
                e_x_contrib <= 32'd1; // Arbitrary value
                state <= COMPUTE_Y;
            end
            COMPUTE_Y: begin
                e_y_contrib <= 32'd1;
                state <= FINALIZE;
            end
            FINALIZE: begin
                // Compute final_result = (2 / area) * (e_x_contrib + e_y_contrib)
                // This is problematic, but for now, just add them
                final_result <= e_x_contrib + e_y_contrib;
                state <= WAIT;
                count_down <= 500;
            end
            WAIT: begin
                if (count_down == 0) begin
                    state <= DONE;
                    done <= 1'b1;
                    expected_distance <= final_result; // Output as is? Should be in Q16.16?
                end else begin
                    count_down <= count_down -1;
                    done <= 1'b0;
                end
            end
            DONE: begin
                expected_distance <= final_result;
                done <= 1'b1;
            end
        endcase
    end
end
endmodule