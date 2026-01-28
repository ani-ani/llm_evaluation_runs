module max_sub_array_repeated (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr_0,
    input wire [15:0] arr_1,
    input wire [15:0] arr_2,
    input wire [15:0] arr_3,
    input wire [15:0] arr_4,
    input wire [15:0] arr_5,
    input wire [15:0] arr_6,
    input wire [15:0] arr_7,
    input wire [3:0] n,
    input wire [3:0] k,
    output reg [31:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_START = 3'd1;
    localparam [2:0] COMPUTE_UPDATE = 3'd2;
    localparam [2:0] COMPUTE_CHECK = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [7:0] iter_count;
    reg signed [31:0] max_so_far;
    reg signed [31:0] max_ending_here;
    reg [3:0] arr_index;
    reg [3:0] repeat_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Wire to hold current array element
    reg signed [15:0] current_val;

    // Combinational lookup for array element
    always @(*) begin
        case(arr_index)
            4'd0: current_val = arr_0;
            4'd1: current_val = arr_1;
            4'd2: current_val = arr_2;
            4'd3: current_val = arr_3;
            4'd4: current_val = arr_4;
            4'd5: current_val = arr_5;
            4'd6: current_val = arr_6;
            4'd7: current_val = arr_7;
            default: current_val = 16'sd0;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            max_so_far <= 32'sh80000000;
            max_ending_here <= 32'sd0;
            iter_count <= 8'd0;
            arr_index <= 4'd0;
            repeat_count <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_START;
                        iter_count <= 8'd0;
                        arr_index <= 4'd0;
                        repeat_count <= 4'd0;
                        max_so_far <= 32'sh80000000;
                        max_ending_here <= 32'sd0;
                    end
                end

                COMPUTE_START: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISHED;
                    end else if (iter_count < (n * k)) begin
                        // Calculate new max_ending_here
                        if (max_ending_here + current_val > 32'sd0) begin
                            max_ending_here <= max_ending_here + current_val;
                        end else begin
                            max_ending_here <= 32'sd0;
                        end
                        state <= COMPUTE_UPDATE;
                    end else begin
                        state <= FINISHED;
                    end
                end

                COMPUTE_UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Update max_so_far
                    if (max_ending_here > max_so_far) begin
                        max_so_far <= max_ending_here;
                    end
                    state <= COMPUTE_CHECK;
                end

                COMPUTE_CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Increment repeat count
                    if (repeat_count + 4'd1 < k) begin
                        repeat_count <= repeat_count + 4'd1;
                        arr_index <= arr_index + 4'd1;
                    end else begin
                        // Move to next element in original array
                        repeat_count <= 4'd0;
                        if (arr_index + 4'd1 < n) begin
                            arr_index <= arr_index + 4'd1;
                        end else begin
                            arr_index <= 4'd0;
                        end
                    end
                    iter_count <= iter_count + 8'd1;
                    state <= COMPUTE_START;
                end

                FINISHED: begin
                    result <= max_so_far;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule