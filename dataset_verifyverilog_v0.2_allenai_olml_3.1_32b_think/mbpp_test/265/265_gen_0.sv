module list_splitter(input clk, input rst_n, // active low input start, input [3:0] step, input [4:0] num_elements, input [7:0] data_in, input data_valid, output reg [1:0] buffer_id, output reg [4:0] buffer_index, output reg [7:0] data_out, output reg write_enable, output reg done);
localparam IDLE = 2'd0;
localparam READ_ELEMENT = 2'd1;
localparam PROCESS = 2'd2;
localparam COMPLETE = 2'd3;
reg [2:0] state;
reg [4:0] counter;
reg [7:0] data_reg;
reg [1:0] buffer_id_reg;
reg [4:0] buffer_index_reg;
reg [7:0] data_out_reg;
reg write_enable_reg;
reg done_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 0;
        data_reg <= 0;
        buffer_id_reg <= 0;
        buffer_index_reg <= 0;
        data_out_reg <= 0;
        write_enable_reg <= 0;
        done_reg <= 0;
    end else begin
        if (start) begin
            state <= READ_ELEMENT;
            counter <= 0;
            data_reg <= 0;
            buffer_id_reg <= 0;
            buffer_index_reg <= 0;
            data_out_reg <= 0;
            write_enable_reg <= 0;
            done_reg <= 0;
        end else begin
            if (state == IDLE) begin
                state <= IDLE;
            end else if (state == READ_ELEMENT) begin
                if (data_valid) begin
                    data_reg <= data_in;
                    state <= PROCESS;
                end
            end else if (state == PROCESS) begin
                buffer_id_reg <= counter % step;
                buffer_index_reg <= counter / step;
                data_out_reg <= data_reg;
                write_enable_reg <= 1'b1;
                counter <= counter + 1;
                if (counter == num_elements) begin
                    done_reg <= 1'b1;
                    state <= COMPLETE;
                end else begin
                    state <= READ_ELEMENT;
                end
            end else if (state == COMPLETE) begin
                // Do nothing
            end
        end
    end
end
assign buffer_id = buffer_id_reg;
assign buffer_index = buffer_index_reg;
assign data_out = data_out_reg;
assign write_enable = write_enable_reg;
assign done = done_reg;
endmodule