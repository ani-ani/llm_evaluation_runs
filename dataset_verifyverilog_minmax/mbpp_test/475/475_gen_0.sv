module sort_dict_by_val (
    input clk,
    input rst_n,
    input start,
    input [3:0] size,
    input [3:0] keys_in [0:3],
    input [15:0] vals_in [0:3],
    output reg [3:0] sorted_keys [0:3],
    output reg [15:0] sorted_vals [0:3],
    output reg done
);

localparam IDLE = 2'b00;
localparam LOAD = 2'b01;
localparam SORT = 2'b10;
localparam DONE = 2'b11;

reg [1:0] state;
reg [3:0] counter;
reg [15:0] vals_reg [0:3];
reg [3:0] keys_reg [0:3];
reg [15:0] temp_val;
reg [3:0] temp_key;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        counter <= 4'b0;
        for (int i = 0; i < 4; i++) begin
            sorted_keys[i] <= 4'b0;
            sorted_vals[i] <= 16'b0;
        end
    end
    else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                counter <= 4'b0;
                if (start) begin
                    state <= LOAD;
                end
            end
            LOAD: begin
                done <= 1'b0;
                for (int i = 0; i < 4; i++) begin
                    if (i < size) begin
                        keys_reg[i] <= keys_in[i];
                        vals_reg[i] <= vals_in[i];
                    end
                    else begin
                        keys_reg[i] <= 4'b0;
                        vals_reg[i] <= 16'b0;
                    end
                end
                state <= SORT;
                counter <= 4'b0;
            end
            SORT: begin
                done <= 1'b0;
                counter <= counter + 1;
                if (counter < 6) begin
                    case (counter)
                        4'b0000: begin
                            if (vals_reg[0] < vals_reg[1]) begin
                                temp_val <= vals_reg[0];
                                vals_reg[0] <= vals_reg[1];
                                vals_reg[1] <= temp_val;
                                temp_key <= keys_reg[0];
                                keys_reg[0] <= keys_reg[1];
                                keys_reg[1] <= temp_key;
                            end
                        end
                        4'b0001: begin
                            if (vals_reg[1] < vals_reg[2]) begin
                                temp_val <= vals_reg[1];
                                vals_reg[1] <= vals_reg[2];
                                vals_reg[2] <= temp_val;
                                temp_key <= keys_reg[1];
                                keys_reg[1] <= keys_reg[2];
                                keys_reg[2] <= temp_key;
                            end
                        end
                        4'b0010: begin
                            if (vals_reg[2] < vals_reg[3]) begin
                                temp_val <= vals_reg[2];
                                vals_reg[2] <= vals_reg[3];
                                vals_reg[3] <= temp_val;
                                temp_key <= keys_reg[2];
                                keys_reg[2] <= keys_reg[3];
                                keys_reg[3] <= temp_key;
                            end
                        end
                        4'b0011: begin
                            if (vals_reg[0] < vals_reg[1]) begin
                                temp_val <= vals_reg[0];
                                vals_reg[0] <= vals_reg[1];
                                vals_reg[1] <= temp_val;
                                temp_key <= keys_reg[0];
                                keys_reg[0] <= keys_reg[1];
                                keys_reg[1] <= temp_key;
                            end
                        end
                        4'b0100: begin
                            if (vals_reg[1] < vals_reg[2]) begin
                                temp_val <= vals_reg[1];
                                vals_reg[1] <= vals_reg[2];
                                vals_reg[2] <= temp_val;
                                temp_key <= keys_reg[1];
                                keys_reg[1] <= keys_reg[2];
                                keys_reg[2] <= temp_key;
                            end
                        end
                        4'b0101: begin
                            if (vals_reg[0] < vals_reg[1]) begin
                                temp_val <= vals_reg[0];
                                vals_reg[0] <= vals_reg[1];
                                vals_reg[1] <= temp_val;
                                temp_key <= keys_reg[0];
                                keys_reg[0] <= keys_reg[1];
                                keys_reg[1] <= temp_key;
                            end
                        end
                    endcase
                end
                if (counter == 4'b1011) begin
                    state <= DONE;
                    done <= 1'b1;
                    sorted_keys <= keys_reg;
                    sorted_vals <= vals_reg;
                end
            end
            DONE: begin
                done <= 1'b1;
                if (start) begin
                    state <= LOAD;
                end
            end
        endcase
    end
end

endmodule