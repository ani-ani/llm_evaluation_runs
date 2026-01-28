module intersperse(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_in [0:15],
    input [3:0] len_in,
    input [7:0] delim,
    output reg [7:0] arr_out [0:31],
    output reg [4:0] len_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [4:0] out_index;
    reg [3:0] in_index;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd50;

    // Initialize all outputs
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            out_index <= 5'd0;
            in_index <= 4'd0;
            cycle_count <= 5'd0;
            done <= 1'b0;
            len_out <= 5'd0;
            for (i = 0; i < 32; i = i + 1) begin
                arr_out[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        out_index <= 5'd0;
                        in_index <= 4'd0;
                        len_out <= (len_in > 4'd0) ? (len_in * 2'd2 - 1'd1) : 5'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 5'd1;
                    if (len_in == 4'd0) begin
                        next_state <= DONE_STATE;
                    end else begin
                        if (in_index < len_in) begin
                            arr_out[out_index] <= arr_in[in_index];
                            out_index <= out_index + 5'd1;
                            if (in_index < len_in - 1'd1) begin
                                arr_out[out_index] <= delim;
                                out_index <= out_index + 5'd1;
                            end
                            in_index <= in_index + 4'd1;
                            if (in_index == len_in) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= PROCESS;
                            end
                        end else begin
                            next_state <= DONE_STATE;
                        end
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
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
        end
    end

endmodule