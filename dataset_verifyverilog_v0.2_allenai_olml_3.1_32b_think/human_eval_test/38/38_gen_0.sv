module cyclic_decode (
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [2:0] str_length,
    input reg [7:0] char_in,
    input reg char_valid,
    output reg [7:0] decoded_char,
    output reg char_out_valid,
    output reg done
);

reg [7:0] input_buf [2:0];
reg [2:0] current_group_idx;
reg [3:0] received_count;
reg [2:0] current_group_size;
reg [2:0] output_index;
reg [2:0] state;
reg [7:0] decoded_group [2:0];

localparam IDLE = 3'b000;
localparam COLLECTING = 3'b001;
localparam OUTPUTTING = 3'b010;
localparam DONE = 3'b100;

always @(*) begin
    if (!rst_n) begin
        input_buf <= 3'b0;
        current_group_idx <= 3'b0;
        received_count <= 4'b0;
        current_group_size <= 3'b0;
        output_index <= 3'b0;
        state <= IDLE;
        done <= 1'b0;
        decoded_group <= 3'b0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= COLLECTING;
                input_buf <= 3'b0;
                current_group_idx <= 3'b0;
                received_count <= 4'b0;
                current_group_size <= 3'b0;
                output_index <= 3'b0;
                done <= 1'b0;
            end
        end else if (state == COLLECTING) begin
            if (char_valid) begin
                if (received_count < str_length) begin
                    input_buf[current_group_idx] <= char_in;
                    current_group_idx <= current_group_idx + 1;
                    received_count <= received_count + 1;
                end
            end

            if ((current_group_idx == 3) || (received_count == str_length)) begin
                if (current_group_idx == 3) begin
                    current_group_size <= 3;
                end else begin
                    current_group_size <= current_group_idx;
                end

                if (current_group_size == 3) begin
                    decoded_group[0] <= input_buf[2];
                    decoded_group[1] <= input_buf[0];
                    decoded_group[2] <= input_buf[1];
                end else if (current_group_size == 1) begin
                    decoded_group[0] <= input_buf[0];
                end else if (current_group_size == 2) begin
                    decoded_group[0] <= input_buf[0];
                    decoded_group[1] <= input_buf[1];
                end

                state <= OUTPUTTING;
                current_group_idx <= 3'b0;
            end
        end else if (state == OUTPUTTING) begin
            if (output_index < current_group_size) begin
                decoded_char <= decoded_group[output_index];
                char_out_valid <= 1'b1;
                output_index <= output_index + 1;
            end else begin
                if (received_count < str_length) begin
                    state <= COLLECTING;
                    input_buf <= 3'b0;
                    current_group_idx <= 3'b0;
                    output_index <= 3'b0;
                end else begin
                    done <= 1'b1;
                    state <= DONE;
                end
            end
        end else if (state == DONE) begin
        end
    end
end
endmodule