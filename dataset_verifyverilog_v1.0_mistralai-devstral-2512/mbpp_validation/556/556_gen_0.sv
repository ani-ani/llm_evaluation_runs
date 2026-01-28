module PairCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    reg [2:0] i;
    reg [2:0] j;
    reg [15:0] counter;
    reg [7:0] xor_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            counter <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 3'd0;
                    j <= 3'd0;
                    counter <= 16'd0;
                    if (start) begin
                        next_state = COMPUTE;
                    end else begin
                        next_state = IDLE;
                    end
                end

                COMPUTE: begin
                    if (j == 7) begin
                        i <= i + 3'd1;
                        j <= i + 3'd1;
                    end else begin
                        j <= j + 3'd1;
                    end

                    xor_result <= arr[i] ^ arr[j];
                    if (xor_result[0] == 1'b1) begin
                        counter <= counter + 16'd1;
                    end

                    if (i == 7 && j == 7) begin
                        next_state = FINISH;
                    end else begin
                        next_state = COMPUTE;
                    end
                end

                FINISH: begin
                    result <= counter;
                    done <= 1'b1;
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end
endmodule