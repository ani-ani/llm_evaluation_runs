module rectangle_intersection(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [15:0] rect_x1 [0:15],
    input wire signed [15:0] rect_y1 [0:15],
    input wire signed [15:0] rect_x2 [0:15],
    input wire signed [15:0] rect_y2 [0:15],
    output reg signed [15:0] result_x,
    output reg signed [15:0] result_y,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_PREFIX = 3'd1;
    localparam [2:0] COMPUTE_SUFFIX = 3'd2;
    localparam [2:0] CHECK_INTERSECTIONS = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd300;

    // Prefix and suffix intersection arrays
    reg signed [31:0] prefix_x1 [0:16];
    reg signed [31:0] prefix_y1 [0:16];
    reg signed [31:0] prefix_x2 [0:16];
    reg signed [31:0] prefix_y2 [0:16];
    reg signed [31:0] suffix_x1 [0:16];
    reg signed [31:0] suffix_y1 [0:16];
    reg signed [31:0] suffix_x2 [0:16];
    reg signed [31:0] suffix_y2 [0:16];

    // Current index for computation
    reg [3:0] current_i;
    reg [3:0] current_j;

    // Temporary storage for intersection
    reg signed [31:0] temp_x1, temp_y1, temp_x2, temp_y2;

    // Found flag
    reg found;

    // Clamp function to prevent overflow
    function signed [31:0] clamp(input signed [31:0] val);
        if (val > 32'd1000000) begin
            clamp = 32'd1000000;
        end else if (val < 32'd-1000000) begin
            clamp = 32'd-1000000;
        end else begin
            clamp = val;
        end
    endfunction

    // Intersection function
    function [3:0] is_valid(input signed [31:0] x1, input signed [31:0] y1, input signed [31:0] x2, input signed [31:0] y2);
        is_valid = (x1 <= x2) && (y1 <= y2);
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_x <= 16'd0;
            result_y <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_i <= 4'd0;
            current_j <= 4'd0;
            found <= 1'b0;

            // Initialize arrays
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                prefix_x1[k] <= 32'd0;
                prefix_y1[k] <= 32'd0;
                prefix_x2[k] <= 32'd0;
                prefix_y2[k] <= 32'd0;
                suffix_x1[k] <= 32'd0;
                suffix_y1[k] <= 32'd0;
                suffix_x2[k] <= 32'd0;
                suffix_y2[k] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_PREFIX;
                        current_i <= 4'd0;
                        found <= 1'b0;
                    end
                end

                COMPUTE_PREFIX: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (current_i == 4'd0) begin
                        // Initialize prefix[0] to first rectangle
                        prefix_x1[0] <= clamp({16'd0, rect_x1[0]});
                        prefix_y1[0] <= clamp({16'd0, rect_y1[0]});
                        prefix_x2[0] <= clamp({16'd0, rect_x2[0]});
                        prefix_y2[0] <= clamp({16'd0, rect_y2[0]});
                        current_i <= current_i + 4'd1;
                    end else if (current_i <= n) begin
                        // Compute intersection of prefix[i-1] and rectangle i-1
                        temp_x1 = clamp(prefix_x1[current_i - 1] > {16'd0, rect_x1[current_i - 1]} ? 
                                        prefix_x1[current_i - 1] : {16'd0, rect_x1[current_i - 1]});
                        temp_y1 = clamp(prefix_y1[current_i - 1] > {16'd0, rect_y1[current_i - 1]} ? 
                                        prefix_y1[current_i - 1] : {16'd0, rect_y1[current_i - 1]});
                        temp_x2 = clamp(prefix_x2[current_i - 1] < {16'd0, rect_x2[current_i - 1]} ? 
                                        prefix_x2[current_i - 1] : {16'd0, rect_x2[current_i - 1]});
                        temp_y2 = clamp(prefix_y2[current_i - 1] < {16'd0, rect_y2[current_i - 1]} ? 
                                        prefix_y2[current_i - 1] : {16'd0, rect_y2[current_i - 1]});

                        prefix_x1[current_i] <= temp_x1;
                        prefix_y1[current_i] <= temp_y1;
                        prefix_x2[current_i] <= temp_x2;
                        prefix_y2[current_i] <= temp_y2;

                        current_i <= current_i + 4'd1;
                    end else begin
                        current_i <= 4'd0;
                        state <= COMPUTE_SUFFIX;
                    end
                end

                COMPUTE_SUFFIX: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (current_i == n - 1) begin
                        // Initialize suffix[n-1] to last rectangle
                        suffix_x1[n - 1] <= clamp({16'd0, rect_x1[n - 1]});
                        suffix_y1[n - 1] <= clamp({16'd0, rect_y1[n - 1]});
                        suffix_x2[n - 1] <= clamp({16'd0, rect_x2[n - 1]});
                        suffix_y2[n - 1] <= clamp({16'd0, rect_y2[n - 1]});
                        current_i <= current_i - 4'd1;
                    end else if (current_i >= 4'd0) begin
                        // Compute intersection of suffix[i+1] and rectangle i
                        temp_x1 = clamp(suffix_x1[current_i + 1] > {16'd0, rect_x1[current_i]} ? 
                                        suffix_x1[current_i + 1] : {16'd0, rect_x1[current_i]});
                        temp_y1 = clamp(suffix_y1[current_i + 1] > {16'd0, rect_y1[current_i]} ? 
                                        suffix_y1[current_i + 1] : {16'd0, rect_y1[current_i]});
                        temp_x2 = clamp(suffix_x2[current_i + 1] < {16'd0, rect_x2[current_i]} ? 
                                        suffix_x2[current_i + 1] : {16'd0, rect_x2[current_i]});
                        temp_y2 = clamp(suffix_y2[current_i + 1] < {16'd0, rect_y2[current_i]} ? 
                                        suffix_y2[current_i + 1] : {16'd0, rect_y2[current_i]});

                        suffix_x1[current_i] <= temp_x1;
                        suffix_y1[current_i] <= temp_y1;
                        suffix_x2[current_i] <= temp_x2;
                        suffix_y2[current_i] <= temp_y2;

                        current_i <= current_i - 4'd1;
                    end else begin
                        current_i <= 4'd0;
                        state <= CHECK_INTERSECTIONS;
                    end
                end

                CHECK_INTERSECTIONS: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (!found && current_i < n) begin
                        // Compute intersection of prefix[i] and suffix[i]
                        temp_x1 = clamp(prefix_x1[current_i] > suffix_x1[current_i] ? 
                                        prefix_x1[current_i] : suffix_x1[current_i]);
                        temp_y1 = clamp(prefix_y1[current_i] > suffix_y1[current_i] ? 
                                        prefix_y1[current_i] : suffix_y1[current_i]);
                        temp_x2 = clamp(prefix_x2[current_i] < suffix_x2[current_i] ? 
                                        prefix_x2[current_i] : suffix_x2[current_i]);
                        temp_y2 = clamp(prefix_y2[current_i] < suffix_y2[current_i] ? 
                                        prefix_y2[current_i] : suffix_y2[current_i]);

                        if (is_valid(temp_x1, temp_y1, temp_x2, temp_y2)) begin
                            // Found valid intersection
                            result_x <= temp_x1[15:0];
                            result_y <= temp_y1[15:0];
                            found <= 1'b1;
                        end

                        current_i <= current_i + 4'd1;
                    end else begin
                        if (found || cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end else begin
                            current_i <= 4'd0;
                            state <= CHECK_INTERSECTIONS;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule