module odd_filter(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr_in [0:7],
    input arr_in_valid,
    output reg signed [7:0] arr_out [0:3],
    output reg [1:0] arr_out_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd8;

    reg [2:0] out_index;
    reg [2:0] in_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_index <= 3'd0;
            in_index <= 3'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            arr_out_len <= 2'd0;
            for (integer i = 0; i < 4; i = i + 1) begin
                arr_out[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && arr_in_valid) begin
                        state <= PROCESS;
                        in_index <= 3'd0;
                        out_index <= 3'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (in_index < 8'd8) begin
                        if ((arr_in[in_index] & 1'b1) == 1'b1) begin
                            arr_out[out_index] <= arr_in[in_index];
                            out_index <= out_index + 3'd1;
                        end
                        in_index <= in_index + 3'd1;
                    end

                    if (in_index >= 8'd8 || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                        arr_out_len <= out_index;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule