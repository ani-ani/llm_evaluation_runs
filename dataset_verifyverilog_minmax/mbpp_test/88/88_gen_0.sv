module frequency_counter #(
    parameter WIDTH = 8,
    parameter N = 16,
    parameter MAXVAL = 256
) (
    input clk,
    input rst_n,
    input start,
    input [WIDTH-1:0] data_in [0:N-1],
    input [WIDTH-1:0] query_key,
    output reg [WIDTH-1:0] frequency_value,
    output reg done
);
    // Frequency count array: 256 entries of 8-bit counters
    reg [WIDTH-1:0] freq [0:MAXVAL-1];
    integer i;
    reg [4:0] idx; // up to 15
    typedef enum logic [1:0] {IDLE, PROCESS, DONE} state_t;
    state_t state;

    // Reset and start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset state
            state <= IDLE;
            done <= 1'b0;
            idx <= 0;
            // clear frequency counts
            for (i = 0; i < MAXVAL; i++) begin
                freq[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // start processing
                        state <= PROCESS;
                        idx <= 0;
                        done <= 1'b0;
                    end
                end
                PROCESS: begin
                    if (idx < N) begin
                        // increment count for the current data element
                        freq[data_in[idx]] <= freq[data_in[idx]] + 1;
                        idx <= idx + 1;
                    end else begin
                        // finished processing all elements
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                DONE: begin
                    // stay in done until a new start is asserted
                    if (start) begin
                        // start new process, re-enter PROCESS
                        state <= PROCESS;
                        idx <= 0;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Combinational query: output the frequency for query_key
    always_comb begin
        frequency_value = freq[query_key];
    end

endmodule
