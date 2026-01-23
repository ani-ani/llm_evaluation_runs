module robber_watches (
    input clk,
    input rst_n, // active-low
    input start,
    input [7:0] n,
    input [7:0] m,
    output reg [15:0] result,
    output reg done
    );

    // State registers
    reg [2:0] state; // IDLE=0, GENERATING=1, CHECKING=2, UPDATE=3, DONE=4
    reg [6:0] count; // up to 119
    reg [4:0] perm [4]; // 5 digits 0-4

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default assignments
        state <= state;
        count <= count;
        result <= result;
        done <= 1'b0;

        if (!rst_n) begin
            state <= 3'b000; // IDLE
            count <= 8'b0;
            done <= 1'b0;
        end else if (start) begin
            if (state == 3'b000) begin // IDLE, start processing
                state <= 3'b001; // GENERATING
                count <= 8'b0;
            end
        end else begin
            case (state)
                3'b000: // IDLE, no start? stay
                    if (start) state <= 3'b001;
                    else state <=3'b000;
                3'b001: // GENERATING: compute permutation
                    if (count < 120) begin
                        // Generate a simple permutation: use count as binary
                        perm[0] = count[4];
                        perm[1] = count[3];
                        perm[2] = count[2];
                        perm[3] = count[1];
                        perm[4] = count[0];
                        state <= 3'b010; // move to CHECKING
                    end else begin
                        state <= 3'b100; // DONE
                    end
                3'b010: // CHECKING
                    // Convert perm to hour and minute
                    reg [9:0] hour_val, minute_val;
                    hour_val = perm[0]*49 + perm[1]*7 + perm[2];
                    minute_val = perm[3]*7 + perm[4];
                    if (hour_val < n && minute_val < m) begin
                        result <= result +1;
                    end
                    state <= 3'b001; // loop
                    if (count == 119) state <=3'b100;
                3'b100: // DONE
                    done <=1'b1;
                default: state <= state;
            endcase
        end
    end

    // Output assignments
    assign result = result;
    assign done = done;

endmodule