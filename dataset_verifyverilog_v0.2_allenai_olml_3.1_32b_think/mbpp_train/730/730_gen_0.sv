module remove_consecutive_duplicates (
    input clk,
    input rst_n,
    input start,
    input [4:0] input_length,
    input [7:0] input_data [15:0],
    output reg [4:0] output_length,
    output reg [7:0] output_data [15:0],
    output reg done
);
localparam IDLE = 2'd0,
          PROCESSING = 2'd1,
          DONE_STATE = 2'd2;

reg [1:0] state;
reg [7:0] stored_input_data [15:0];
reg [4:0] stored_input_length;
reg [4:0] output_length_reg;
reg [7:0] output_data_reg [15:0];
reg [3:0] idx;
reg done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        stored_input_data <= 16'd0;
        stored_input_length <= 4'd0;
        output_length_reg <= 4'd0;
        output_data_reg <= 16'd0;
        idx <= 4'd0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    stored_input_data <= input_data;
                    stored_input_length <= input_length;
                    output_length_reg <= 4'd0;
                    output_data_reg <= 16'd0;
                    idx <= 4'd0;
                    done_reg <= 1'b0;
                    state <= PROCESSING;
                end
            end
            PROCESSING: begin
                if (idx < stored_input_length) begin
                    if (idx == 0) begin
                        output_data_reg[idx] <= stored_input_data[idx];
                        output_length_reg <= 1;
                    end else begin
                        if (stored_input_data[idx] != stored_input_data[idx-1]) begin
                            output_data_reg[output_length_reg] <= stored_input_data[idx];
                            output_length_reg <= output_length_reg + 1;
                        end
                    end
                    idx <= idx + 1;
                end else begin
                    done_reg <= 1'b1;
                    state <= DONE_STATE;
                end
            end
            DONE_STATE: begin
            end
        endcase
    end
end

assign output_length = output_length_reg;
assign output_data = output_data_reg;
assign done = done_reg;

endmodule