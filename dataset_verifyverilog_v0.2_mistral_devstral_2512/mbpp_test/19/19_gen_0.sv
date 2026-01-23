module duplicate_finder #(
    parameter N = 8,
    parameter W = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N-1:0][W-1:0] array_in,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] i, j; // Indices for nested loops (N=8 fits in 4 bits)
    reg found_dup;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic and Output Logic (Moore style)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
            end
            PROCESSING: begin
                // Completion condition: i reaches N or duplicate found
                if (i == N || found_dup) next_state = DONE;
            end
            DONE: begin
                // Stay in DONE until reset
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            found_dup <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                    i <= 1;      // Start outer loop at 1
                    j <= 0;      // Start inner loop at 0
                    found_dup <= 0;
                end

                PROCESSING: begin
                    // If we haven't reached the end of the array
                    if (i < N) begin
                        // Compare elements
                        if (array_in[i] == array_in[j]) begin
                            found_dup <= 1; // Duplicate found
                            result <= 1;
                        end

                        // Update indices
                        j <= j + 1;
                        if (j + 1 == i) begin // If j was the last element before i
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        // i == N, loops finished. result is already 0 (default)
                        // State machine will transition to DONE next cycle
                    end
                end

                DONE: begin
                    done <= 1;
                    // Keep result value
                end
            endcase
        end
    end

endmodule