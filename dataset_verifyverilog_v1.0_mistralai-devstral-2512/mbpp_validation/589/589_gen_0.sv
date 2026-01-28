module perfect_square_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [7:0] result [0:15],
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] i;  // Counter for 1-16
    reg [7:0] square;
    reg [3:0] temp_count;
    reg [7:0] temp_result [0:15];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i <= 4'd0;
            square <= 8'd0;
            temp_count <= 4'd0;
            done <= 1'b0;
            count <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize result array
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                result[j] <= 8'd0;
                temp_result[j] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        i <= 4'd1;
                        temp_count <= 4'd0;
                        // Clear temp_result array
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            temp_result[k] <= 8'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    square <= i * i;

                    // Check if square is within [a, b]
                    if (square >= a && square <= b) begin
                        temp_result[temp_count] <= square;
                        temp_count <= temp_count + 4'd1;
                    end

                    // Move to next i
                    if (i < 4'd16) begin
                        i <= i + 4'd1;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    count <= temp_count;
                    // Copy temp_result to result
                    integer m;
                    for (m = 0; m < 16; m = m + 1) begin
                        result[m] <= temp_result[m];
                    end
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule