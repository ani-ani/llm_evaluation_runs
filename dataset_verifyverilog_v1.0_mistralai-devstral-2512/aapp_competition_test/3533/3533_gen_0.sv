module MinimalTollCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] entrance_i [0:15],
    input wire [15:0] exit_i [0:15],
    input wire [3:0] num_trucks,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SORTING   = 2'd1;
    localparam [1:0] COMPUTING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] sorted_entrance [0:15];
    reg [15:0] sorted_exit [0:15];
    reg [31:0] sum;
    reg [3:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Sorting network for 16 elements (bubble sort style)
    integer i, j;
    reg [15:0] temp_entrance, temp_exit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            index <= 4'd0;
            sum <= 32'd0;
            // Initialize sorted arrays
            for (i = 0; i < 16; i = i + 1) begin
                sorted_entrance[i] <= 16'd0;
                sorted_exit[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    // Initialize sorted arrays with input values
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < num_trucks) begin
                            sorted_entrance[i] = entrance_i[i];
                            sorted_exit[i] = exit_i[i];
                        end else begin
                            sorted_entrance[i] = 16'd0;
                            sorted_exit[i] = 16'd0;
                        end
                    end
                    next_state = SORTING;
                    cycle_count = 8'd0;
                    index = 4'd0;
                    sum = 32'd0;
                end
            end

            SORTING: begin
                // Bubble sort implementation
                if (cycle_count < 16'd240) begin  // 16*15 comparisons
                    for (i = 0; i < 15; i = i + 1) begin
                        if (sorted_entrance[i] > sorted_entrance[i+1]) begin
                            temp_entrance = sorted_entrance[i];
                            sorted_entrance[i] = sorted_entrance[i+1];
                            sorted_entrance[i+1] = temp_entrance;
                        end
                        if (sorted_exit[i] > sorted_exit[i+1]) begin
                            temp_exit = sorted_exit[i];
                            sorted_exit[i] = sorted_exit[i+1];
                            sorted_exit[i+1] = temp_exit;
                        end
                    end
                    cycle_count = cycle_count + 8'd1;
                end else begin
                    next_state = COMPUTING;
                    index = 4'd0;
                    sum = 32'd0;
                end
            end

            COMPUTING: begin
                if (index < num_trucks) begin
                    // Compute absolute difference
                    if (sorted_entrance[index] > sorted_exit[index]) begin
                        sum = sum + (sorted_entrance[index] - sorted_exit[index]);
                    end else begin
                        sum = sum + (sorted_exit[index] - sorted_entrance[index]);
                    end
                    index = index + 4'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
        end else begin
            if (state == DONE_STATE) begin
                result <= sum;
            end
        end
    end

endmodule