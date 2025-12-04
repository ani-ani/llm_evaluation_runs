module list_packer(
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] data_in,
    input [3:0] length_in,
    output reg [3:0] group_count,
    output reg [15:0][3:0] start_indices,
    output reg [15:0][3:0] group_lengths,
    output reg done
);

    reg [1:0] state;
    reg [3:0] i;
    reg [3:0] groups_collected;
    reg [3:0] current_group_start;
    reg [3:0] current_group_length;
    reg [7:0] current_value;
    reg [15:0][3:0] start_indices_int;
    reg [15:0][3:0] group_lengths_int;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 2'b0;
            done <= 1'b0;
            group_count <= 4'b0;
            start_indices <= 16'b0;
            group_lengths <= 16'b0;
            i <= 4'b0;
            groups_collected <= 4'b0;
            current_group_start <= 4'b0;
            current_group_length <= 4'b0;
            current_value <= 8'b0;
            start_indices_int <= 16'b0;
            group_lengths_int <= 16'b0;
        end
        else begin
            case (state)
                2'b00: begin // IDLE
                    if (start) begin
                        i <= 4'b0;
                        groups_collected <= 4'b0;
                        current_group_start <= 4'b0;
                        current_group_length <= 4'b1;
                        current_value <= data_in[0];
                        state <= 2'b01;
                    end
                end
                2'b01: begin // PROCESS
                    if (i < length_in) begin
                        if (i == 4'b0) begin
                            if (length_in == 4'b1) begin
                                start_indices_int[0] <= 4'b0;
                                group_lengths_int[0] <= 4'b1;
                                groups_collected <= 4'b1;
                                group_count <= 4'b1;
                                start_indices <= start_indices_int;
                                group_lengths <= group_lengths_int;
                                done <= 1'b1;
                                state <= 2'b00;
                            end
                            else begin
                                i <= 4'b1;
                            end
                        end
                        else begin
                            if (data_in[i] == current_value) begin
                                current_group_length <= current_group_length + 1;
                            end
                            else begin
                                start_indices_int[groups_collected] <= current_group_start;
                                group_lengths_int[groups_collected] <= current_group_length;
                                groups_collected <= groups_collected + 1;
                                current_group_start <= i;
                                current_group_length <= 4'b1;
                                current_value <= data_in[i];
                            end

                            if (i == length_in - 1) begin
                                start_indices_int[groups_collected] <= current_group_start;
                                group_lengths_int[groups_collected] <= current_group_length;
                                groups_collected <= groups_collected + 1;
                                group_count <= groups_collected;
                                start_indices <= start_indices_int;
                                group_lengths <= group_lengths_int;
                                done <= 1'b1;
                                state <= 2'b00;
                            end
                            else begin
                                i <= i + 1;
                            end
                        end
                    end
                    else begin
                        state <= 2'b00;
                    end
                end
                default: state <= 2'b00;
            endcase
        end
    end
endmodule