module FoodAssignment (
    input clk,
    input rst_n,
    input config_en,
    input [3:0] a_in,
    input [3:0] b_in,
    input [3:0] n,
    output reg done,
    output reg output_valid,
    output reg [2:0] output_index,
    output reg [1:0] output_boy,
    output reg [1:0] output_girl
);

    // Internal arrays (0-15 for chairs, 0-7 for couples)
    reg [3:0] couple_list_a [0:7];
    reg [3:0] couple_list_b [0:7];
    reg [3:0] partner [0:15];
    reg [1:0] food [0:15];

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CONFIG   = 3'd1;
    localparam [2:0] RUN      = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Run state definitions
    localparam [1:0] FIND_NEXT = 2'd0;
    localparam [1:0] CHAIN     = 2'd1;

    // Registers
    reg [2:0] state;
    reg [2:0] config_index;
    reg [3:0] i_reg;
    reg [3:0] temp_j;
    reg [1:0] assign_state;
    reg [3:0] max_chairs;
    reg [2:0] output_counter;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            config_index <= 3'd0;
            done <= 1'b1;
            output_valid <= 1'b0;
            output_index <= 3'd0;
            output_boy <= 2'd0;
            output_girl <= 2'd0;
            i_reg <= 4'd0;
            temp_j <= 4'd0;
            assign_state <= FIND_NEXT;
            max_chairs <= 4'd0;
            output_counter <= 3'd0;

            // Reset arrays
            for (i = 0; i < 16; i = i + 1) begin
                partner[i] <= 4'd0;
                food[i] <= 2'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                couple_list_a[i] <= 4'd0;
                couple_list_b[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    output_valid <= 1'b0;
                    if (config_en) begin
                        couple_list_a[config_index] <= a_in;
                        couple_list_b[config_index] <= b_in;
                        partner[a_in] <= b_in;
                        partner[b_in] <= a_in;
                        config_index <= config_index + 3'd1;
                        state <= CONFIG;
                    end
                end

                CONFIG: begin
                    if (config_en) begin
                        if (config_index < 3'd8) begin
                            couple_list_a[config_index] <= a_in;
                            couple_list_b[config_index] <= b_in;
                            partner[a_in] <= b_in;
                            partner[b_in] <= a_in;
                            config_index <= config_index + 3'd1;
                        end
                    end
                    // Transition to RUN when all couples configured
                    if (config_index == n && !config_en) begin
                        state <= RUN;
                        i_reg <= 4'd0;
                        assign_state <= FIND_NEXT;
                        max_chairs <= {n[3:0], 1'b0}; // 2*n
                    end
                end

                RUN: begin
                    case (assign_state)
                        FIND_NEXT: begin
                            if (i_reg >= max_chairs) begin
                                state <= OUTPUT;
                                output_counter <= 3'd0;
                                output_index <= 3'd0;
                                output_valid <= 1'b1;
                                output_boy <= food[couple_list_a[0]];
                                output_girl <= food[couple_list_b[0]];
                            end else if (food[i_reg] != 2'd0) begin
                                i_reg <= i_reg + 4'd1;
                            end else begin
                                temp_j <= i_reg;
                                assign_state <= CHAIN;
                            end
                        end

                        CHAIN: begin
                            if (food[temp_j] != 2'd0) begin
                                i_reg <= i_reg + 4'd1;
                                assign_state <= FIND_NEXT;
                            end else begin
                                food[temp_j] <= 2'd1;
                                food[temp_j ^ 4'd1] <= 2'd2;
                                temp_j <= partner[temp_j ^ 4'd1];
                            end
                        end
                    endcase
                end

                OUTPUT: begin
                    if (output_counter < n - 3'd1) begin
                        output_counter <= output_counter + 3'd1;
                        output_index <= output_counter + 3'd1;
                        output_boy <= food[couple_list_a[output_counter + 3'd1]];
                        output_girl <= food[couple_list_b[output_counter + 3'd1]];
                    end else begin
                        output_valid <= 1'b0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    config_index <= 3'd0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule