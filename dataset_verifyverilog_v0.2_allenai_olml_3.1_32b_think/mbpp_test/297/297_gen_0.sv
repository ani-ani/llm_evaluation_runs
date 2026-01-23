module flatten_list (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_subarrays,
    input [3:0] subarray_lengths [0:3],
    input [7:0] data_in [0:15],
    output reg [7:0] flattened [0:15],
    output reg [4:0] output_length,
    output reg done
);

localparam IDLE = 3'd0, READING=3'd1, WRITING=3'd2, DONE=3'd3;

reg [2:0] state;
reg [3:0] counter;
reg [3:0] total_length;
reg [4:0] output_length_reg;
reg [7:0] flattened_reg [0:15];
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 0;
        total_length <= 0;
        output_length_reg <= 0;
        done_reg <= 0;
        flattened_reg <= {16{8'b0}};
    end else begin
        if (state == IDLE) begin
            if (start) begin
                total_length <= subarray_lengths[0];
                if (num_subarrays > 1) total_length <= total_length + subarray_lengths[1];
                if (num_subarrays > 2) total_length <= total_length + subarray_lengths[2];
                if (num_subarrays > 3) total_length <= total_length + subarray_lengths[3];
                state <= READING;
                counter <= 0;
                output_length_reg <= total_length;
            end
        end else if (state == READING) begin
            if (counter < 16) begin
                if (counter < total_length) begin
                    flattened_reg[counter] <= data_in[counter];
                end
                counter <= counter + 1;
                if (counter == 16) begin
                    state <= WRITING;
                end else begin
                    state <= READING;
                end
            end
        end else if (state == WRITING) begin
            state <= DONE;
            done_reg <= 1;
        end else if (state == DONE) begin
            // Stay in DONE
        end
    end
end

// Assign outputs
assign done = done_reg;
assign output_length = output_length_reg;
assign flattened = flattened_reg;

endmodule