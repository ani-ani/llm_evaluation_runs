module min_k_records (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [7:0] name_0,
    input wire [7:0] name_1,
    input wire [7:0] name_2,
    input wire [7:0] name_3,
    input wire [7:0] score_0,
    input wire [7:0] score_1,
    input wire [7:0] score_2,
    input wire [7:0] score_3,
    input wire [1:0] k,
    
    output reg [7:0] out_name_0,
    output reg [7:0] out_score_0,
    output reg [7:0] out_name_1,
    output reg [7:0] out_score_1,
    output reg [7:0] out_name_2,
    output reg [7:0] out_score_2,
    
    output reg done
);

    localparam [2:0] NUM_RECORDS = 3'd4;
    
    reg [7:0] sort_name [0:3];
    reg [7:0] sort_score [0:3];
    
    reg [2:0] state;
    reg [2:0] sort_counter;
    reg [1:0] pair_counter;
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT_PASS = 3'd2;
    localparam [2:0] SORT_COMPARE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [7:0] temp_name;
    reg [7:0] temp_score;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                sort_name[i] <= 8'h00;
                sort_score[i] <= 8'h00;
            end
            out_name_0 <= 8'h00;
            out_score_0 <= 8'h00;
            out_name_1 <= 8'h00;
            out_score_1 <= 8'h00;
            out_name_2 <= 8'h00;
            out_score_2 <= 8'h00;
            sort_counter <= 3'd0;
            pair_counter <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    sort_name[0] <= name_0;
                    sort_score[0] <= score_0;
                    sort_name[1] <= name_1;
                    sort_score[1] <= score_1;
                    sort_name[2] <= name_2;
                    sort_score[2] <= score_2;
                    sort_name[3] <= name_3;
                    sort_score[3] <= score_3;
                    sort_counter <= 3'd3;
                    pair_counter <= 2'd0;
                    state <= SORT_PASS;
                end
                
                SORT_PASS: begin
                    if (sort_counter > 0) begin
                        pair_counter <= 2'd0;
                        state <= SORT_COMPARE;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                SORT_COMPARE: begin
                    if (pair_counter < 3) begin
                        if (sort_score[pair_counter] > sort_score[pair_counter + 1]) begin
                            temp_name <= sort_name[pair_counter];
                            temp_score <= sort_score[pair_counter];
                            sort_name[pair_counter] <= sort_name[pair_counter + 1];
                            sort_score[pair_counter] <= sort_score[pair_counter + 1];
                            sort_name[pair_counter + 1] <= temp_name;
                            sort_score[pair_counter + 1] <= temp_score;
                        end
                        pair_counter <= pair_counter + 1;
                        state <= SORT_COMPARE;
                    end else begin
                        sort_counter <= sort_counter - 1;
                        state <= SORT_PASS;
                    end
                end
                
                OUTPUT: begin
                    out_name_0 <= sort_name[0];
                    out_score_0 <= sort_score[0];
                    
                    if (k >= 2'd2) begin
                        out_name_1 <= sort_name[1];
                        out_score_1 <= sort_score[1];
                    end else begin
                        out_name_1 <= 8'h00;
                        out_score_1 <= 8'h00;
                    end
                    
                    if (k >= 2'd3) begin
                        out_name_2 <= sort_name[2];
                        out_score_2 <= sort_score[2];
                    end else begin
                        out_name_2 <= 8'h00;
                        out_score_2 <= 8'h00;
                    end
                    
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