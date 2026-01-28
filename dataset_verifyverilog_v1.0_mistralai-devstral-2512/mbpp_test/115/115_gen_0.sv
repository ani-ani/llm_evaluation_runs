module dict_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] list_data,
    input wire [1:0] num_dicts,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [1:0] current_dict;
    reg [1:0] dict_count;
    reg all_empty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_dict <= 2'd0;
            dict_count <= 2'd0;
            all_empty <= 1'b1;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PROCESSING;
                        current_dict <= 2'd0;
                        dict_count <= num_dicts;
                        all_empty <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    // Check current dictionary
                    if (list_data[(current_dict * 16) + 15 : current_dict * 16] != 16'd0) begin
                        all_empty <= 1'b0;
                    end

                    // Move to next dictionary
                    current_dict <= current_dict + 2'd1;

                    // Check if done processing
                    if (current_dict == dict_count) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= PROCESSING;
                    end
                end

                DONE_STATE: begin
                    result <= all_empty;
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