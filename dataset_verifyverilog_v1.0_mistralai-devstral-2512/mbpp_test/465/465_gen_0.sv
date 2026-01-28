module dict_drop_empty (
    input clk,
    input rst_n,
    input start,
    input [3:0] key_in [0:7],
    input [7:0] val_in [0:7],
    input [7:0] valid_in,
    output reg [3:0] key_out [0:7],
    output reg [7:0] val_out [0:7],
    output reg [7:0] valid_out,
    output reg [3:0] result_count,
    output reg done
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS = 4'd1;
    localparam [3:0] OUTPUT = 4'd2;
    localparam [3:0] DONE_STATE = 4'd3;

    reg [3:0] state;
    reg [3:0] cycle_count;
    reg [3:0] input_index;
    reg [3:0] output_index;
    reg [3:0] temp_result_count;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 4'd0;
            input_index <= 4'd0;
            output_index <= 4'd0;
            temp_result_count <= 4'd0;
            done <= 1'b0;
            result_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                key_out[i] <= 4'd0;
                val_out[i] <= 8'd0;
            end
            valid_out <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        cycle_count <= 4'd0;
                        input_index <= 4'd0;
                        output_index <= 4'd0;
                        temp_result_count <= 4'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count < 4'd16) begin
                        if (input_index < 4'd8) begin
                            if (valid_in[input_index] && val_in[input_index] != 8'hFF) begin
                                key_out[output_index] <= key_in[input_index];
                                val_out[output_index] <= val_in[input_index];
                                valid_out[output_index] <= 1'b1;
                                output_index <= output_index + 4'd1;
                                temp_result_count <= temp_result_count + 4'd1;
                            end
                            input_index <= input_index + 4'd1;
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_count <= temp_result_count;
                    state <= DONE_STATE;
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