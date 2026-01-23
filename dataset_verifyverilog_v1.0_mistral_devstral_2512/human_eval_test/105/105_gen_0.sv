module by_length_processor(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [31:0] result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7,
    output reg [3:0] valid_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FILTER  = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] REVERSE = 3'd3;
    localparam [2:0] MAP     = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Temporary buffer for filtered values (max 8 elements)
    reg [7:0] filtered [0:7];
    reg [3:0] filtered_count;

    // Sorting variables
    reg [7:0] sorted [0:7];
    reg [3:0] sort_pass;
    reg [3:0] sort_i;
    reg [3:0] sort_j;

    // Reverse variables
    reg [7:0] reversed [0:7];

    // Mapping variables
    reg [3:0] map_index;

    // String constants
    localparam [31:0] ONE   = 32'h4F6E6500;
    localparam [31:0] TWO   = 32'h54776F00;
    localparam [31:0] THREE = 32'h54687265;
    localparam [31:0] FOUR  = 32'h466F7572;
    localparam [31:0] FIVE  = 32'h46697665;
    localparam [31:0] SIX   = 32'h53697800;
    localparam [31:0] SEVEN = 32'h53657665;
    localparam [31:0] EIGHT = 32'h45696768;
    localparam [31:0] NINE  = 32'h4E696E65;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid_count <= 4'd0;

            // Initialize all outputs
            result_0 <= 32'd0;
            result_1 <= 32'd0;
            result_2 <= 32'd0;
            result_3 <= 32'd0;
            result_4 <= 32'd0;
            result_5 <= 32'd0;
            result_6 <= 32'd0;
            result_7 <= 32'd0;

            // Initialize temporary buffers
            filtered_count <= 4'd0;
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                filtered[i] <= 8'd0;
                sorted[i] <= 8'd0;
                reversed[i] <= 8'd0;
            end

            // Initialize sorting variables
            sort_pass <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;

            // Initialize mapping variables
            map_index <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FILTER;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FILTER: begin
                    // Filter values 1-9 from input array
                    filtered_count <= 4'd0;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (arr[i] >= 8'd1 && arr[i] <= 8'd9) begin
                            filtered[filtered_count] <= arr[i];
                            filtered_count <= filtered_count + 4'd1;
                        end
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    if (sort_pass < 4'd8) begin
                        if (sort_i < 4'd7) begin
                            if (sorted[sort_i] > sorted[sort_i + 4'd1]) begin
                                // Swap
                                reg [7:0] temp;
                                temp = sorted[sort_i];
                                sorted[sort_i] = sorted[sort_i + 4'd1];
                                sorted[sort_i + 4'd1] = temp;
                            end
                            sort_i <= sort_i + 4'd1;
                        end else begin
                            sort_i <= 4'd0;
                            sort_pass <= sort_pass + 4'd1;
                        end
                    end else begin
                        // Copy filtered to sorted at start of sort
                        if (sort_pass == 4'd0 && sort_i == 4'd0) begin
                            integer i;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < filtered_count) begin
                                    sorted[i] <= filtered[i];
                                end else begin
                                    sorted[i] <= 8'd0;
                                end
                            end
                        end
                        // Sort complete
                        next_state <= REVERSE;
                        sort_pass <= 4'd0;
                        sort_i <= 4'd0;
                    end
                end

                REVERSE: begin
                    // Reverse the sorted array
                    integer i;
                    for (i = 0; i < 4; i = i + 1) begin
                        reg [7:0] temp;
                        temp = sorted[i];
                        reversed[i] <= sorted[7 - i];
                        reversed[7 - i] <= temp;
                    end
                    next_state <= MAP;
                end

                MAP: begin
                    // Map digits to their English names
                    if (map_index < filtered_count) begin
                        case (reversed[map_index])
                            8'd1: begin
                                case (map_index)
                                    4'd0: result_0 <= ONE;
                                    4'd1: result_1 <= ONE;
                                    4'd2: result_2 <= ONE;
                                    4'd3: result_3 <= ONE;
                                    4'd4: result_4 <= ONE;
                                    4'd5: result_5 <= ONE;
                                    4'd6: result_6 <= ONE;
                                    4'd7: result_7 <= ONE;
                                endcase
                            end
                            8'd2: begin
                                case (map_index)
                                    4'd0: result_0 <= TWO;
                                    4'd1: result_1 <= TWO;
                                    4'd2: result_2 <= TWO;
                                    4'd3: result_3 <= TWO;
                                    4'd4: result_4 <= TWO;
                                    4'd5: result_5 <= TWO;
                                    4'd6: result_6 <= TWO;
                                    4'd7: result_7 <= TWO;
                                endcase
                            end
                            8'd3: begin
                                case (map_index)
                                    4'd0: result_0 <= THREE;
                                    4'd1: result_1 <= THREE;
                                    4'd2: result_2 <= THREE;
                                    4'd3: result_3 <= THREE;
                                    4'd4: result_4 <= THREE;
                                    4'd5: result_5 <= THREE;
                                    4'd6: result_6 <= THREE;
                                    4'd7: result_7 <= THREE;
                                endcase
                            end
                            8'd4: begin
                                case (map_index)
                                    4'd0: result_0 <= FOUR;
                                    4'd1: result_1 <= FOUR;
                                    4'd2: result_2 <= FOUR;
                                    4'd3: result_3 <= FOUR;
                                    4'd4: result_4 <= FOUR;
                                    4'd5: result_5 <= FOUR;
                                    4'd6: result_6 <= FOUR;
                                    4'd7: result_7 <= FOUR;
                                endcase
                            end
                            8'd5: begin
                                case (map_index)
                                    4'd0: result_0 <= FIVE;
                                    4'd1: result_1 <= FIVE;
                                    4'd2: result_2 <= FIVE;
                                    4'd3: result_3 <= FIVE;
                                    4'd4: result_4 <= FIVE;
                                    4'd5: result_5 <= FIVE;
                                    4'd6: result_6 <= FIVE;
                                    4'd7: result_7 <= FIVE;
                                endcase
                            end
                            8'd6: begin
                                case (map_index)
                                    4'd0: result_0 <= SIX;
                                    4'd1: result_1 <= SIX;
                                    4'd2: result_2 <= SIX;
                                    4'd3: result_3 <= SIX;
                                    4'd4: result_4 <= SIX;
                                    4'd5: result_5 <= SIX;
                                    4'd6: result_6 <= SIX;
                                    4'd7: result_7 <= SIX;
                                endcase
                            end
                            8'd7: begin
                                case (map_index)
                                    4'd0: result_0 <= SEVEN;
                                    4'd1: result_1 <= SEVEN;
                                    4'd2: result_2 <= SEVEN;
                                    4'd3: result_3 <= SEVEN;
                                    4'd4: result_4 <= SEVEN;
                                    4'd5: result_5 <= SEVEN;
                                    4'd6: result_6 <= SEVEN;
                                    4'd7: result_7 <= SEVEN;
                                endcase
                            end
                            8'd8: begin
                                case (map_index)
                                    4'd0: result_0 <= EIGHT;
                                    4'd1: result_1 <= EIGHT;
                                    4'd2: result_2 <= EIGHT;
                                    4'd3: result_3 <= EIGHT;
                                    4'd4: result_4 <= EIGHT;
                                    4'd5: result_5 <= EIGHT;
                                    4'd6: result_6 <= EIGHT;
                                    4'd7: result_7 <= EIGHT;
                                endcase
                            end
                            8'd9: begin
                                case (map_index)
                                    4'd0: result_0 <= NINE;
                                    4'd1: result_1 <= NINE;
                                    4'd2: result_2 <= NINE;
                                    4'd3: result_3 <= NINE;
                                    4'd4: result_4 <= NINE;
                                    4'd5: result_5 <= NINE;
                                    4'd6: result_6 <= NINE;
                                    4'd7: result_7 <= NINE;
                                endcase
                            end
                            default: begin
                                case (map_index)
                                    4'd0: result_0 <= 32'd0;
                                    4'd1: result_1 <= 32'd0;
                                    4'd2: result_2 <= 32'd0;
                                    4'd3: result_3 <= 32'd0;
                                    4'd4: result_4 <= 32'd0;
                                    4'd5: result_5 <= 32'd0;
                                    4'd6: result_6 <= 32'd0;
                                    4'd7: result_7 <= 32'd0;
                                endcase
                            end
                        endcase
                        map_index <= map_index + 4'd1;
                    end else begin
                        valid_count <= filtered_count;
                        next_state <= DONE_STATE;
                        map_index <= 4'd0;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
                cycle_count <= 8'd0;
            end
        end
    end

endmodule