module EvenNumberFilter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [7:0] result [0:7],
    output reg [3:0] result_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers and variables
    reg [1:0] state;
    reg [3:0] idx;           // Current index in input array
    reg [3:0] result_idx;    // Current index in result array
    reg [7:0] temp_arr [0:15];  // Copy of input array for processing
    reg [3:0] temp_len;      // Copy of length
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLES = 4'd15;  // 16 elements max

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 4'd0;
            idx <= 4'd0;
            result_idx <= 4'd0;
            cycle_counter <= 4'd0;
            temp_len <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                temp_arr[i] <= 8'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_count <= 4'd0;
                    idx <= 4'd0;
                    result_idx <= 4'd0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        state <= PROCESS;
                        temp_len <= len;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < len) begin
                                temp_arr[i] <= arr[i];
                            end else begin
                                temp_arr[i] <= 8'd0;
                            end
                        end
                        for (i = 0; i < 8; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                    end
                end

                PROCESS: begin
                    if (idx < temp_len && result_idx < 4'd8 && cycle_counter < MAX_CYCLES) begin
                        // Check if even (num % 2 == 0)
                        // Using bitwise AND: if LSB is 0, it's even
                        if (temp_arr[idx][0] == 1'b0) begin
                            result[result_idx] <= temp_arr[idx];
                            result_idx <= result_idx + 4'd1;
                            result_count <= result_count + 4'd1;
                        end
                        idx <= idx + 4'd1;
                        cycle_counter <= cycle_counter + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule