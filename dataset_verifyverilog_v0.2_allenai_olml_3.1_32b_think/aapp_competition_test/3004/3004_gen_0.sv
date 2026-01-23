module fence_painter (
    input clk,
    input rst_n,
    input start,
    input [1:0] offer_color,
    input [4:0] offer_start,
    input [4:0] offer_end,
    input [1:0] offer_index,
    input offer_valid,
    output reg [2:0] result,
    output reg done,
    output reg possible
);

localparam IDLE = 3'd0,
        LOAD = 1,
        SORT =2,
        PROCESS=3,
        DONE=4;

reg [2:0] state;
reg [1:0] expected_index;
reg [11:0] offers [3:0];

reg [2:0] sort_step;
reg [11:0] temp_offer;

reg [4:0] current_position;
reg [3:0] used_colors;
reg [2:0] offer_count;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        expected_index <=0;
        offers[0] <=0;
        offers[1] <=0;
        offers[2] <=0;
        offers[3] <=0;
        sort_step <=0;
        current_position <=0;
        used_colors <=0;
        offer_count <=0;
        result <=0;
        done <=0;
        possible <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD;
                    expected_index <=0;
                    offers[0] <=0;
                    offers[1] <=0;
                    offers[2] <=0;
                    offers[3] <=0;
                end
            end
            LOAD: begin
                if (offer_valid && (offer_index == expected_index)) begin
                    offers[expected_index] <= {offer_color, offer_start, offer_end};
                    expected_index <= expected_index +1;
                    if (expected_index ==4) begin
                        state <= SORT;
                    end
                end
            end
            SORT: begin
                if (sort_step <6) begin
                    case (sort_step)
                        0: begin
                            if (offers[0][9:5] > offers[1][9:5]) begin
                                temp_offer = offers[0];
                                offers[0] = offers[1];
                                offers[1] = temp_offer;
                            end
                        end
                        1: begin
                            if (offers[1][9:5] > offers[2][9:5]) begin
                                temp_offer = offers[1];
                                offers[1] = offers[2];
                                offers[2] = temp_offer;
                            end
                        end
                        2: begin
                            if (offers[2][9:5] > offers[3][9:5]) begin
                                temp_offer = offers[2];
                                offers[2] = offers[3];
                                offers[3] = temp_offer;
                            end
                        end
                        3: begin
                            if (offers[0][9:5] > offers[1][9:5]) begin
                                temp_offer = offers[0];
                                offers[0] = offers[1];
                                offers[1] = temp_offer;
                            end
                        end
                        4: begin
                            if (offers[1][9:5] > offers[2][9:5]) begin
                                temp_offer = offers[1];
                                offers[1] = offers[2];
                                offers[2] = temp_offer;
                            end
                        end
                        5: begin
                            if (offers[0][9:5] > offers[1][9:5]) begin
                                temp_offer = offers[0];
                                offers[0] = offers[1];
                                offers[1] = temp_offer;
                            end
                        end
                    endcase
                    sort_step <= sort_step +1;
                end
            end
            PROCESS: begin
                if (current_position > 16) begin
                    done <=1;
                    result <= offer_count;
                    possible <=1;
                    state <= DONE;
                end else begin
                    int best_end = -1;
                    int best_i = -1;

                    int color_val0 = offers[0][11:10];
                    int start_val0 = offers[0][9:5];
                    int end_val0 = offers[0][4:0];
                    int eligible0 =0;
                    if (start_val0 <= current_position) begin
                        if ( (used_colors & (1 << color_val0)) !=0 ) begin
                            eligible0 =1;
                        end else begin
                            int cnt =0;
                            if (used_colors[3]) cnt +=1;
                            if (used_colors[2]) cnt +=1;
                            if (used_colors[1]) cnt +=1;
                            if (used_colors[0]) cnt +=1;
                            if (cnt <3) begin
                                eligible0 =1;
                            end
                        end
                    end
                    if (eligible0) begin
                        if (best_end == -1 || end_val0 > best_end) begin
                            best_end = end_val0;
                            best_i =0;
                        end
                    end

                    int color_val1 = offers[1][11:10];
                    int start_val1 = offers[1][9:5];
                    int end_val1 = offers[1][4:0];
                    int eligible1 =0;
                    if (start_val1 <= current_position) begin
                        if ( (used_colors & (1 << color_val1)) !=0 ) begin
                            eligible1 =1;
                        end else begin
                            int cnt =0;
                            if (used_colors[3]) cnt +=1;
                            if (used_colors[2]) cnt +=1;
                            if (used_colors[1]) cnt +=1;
                            if (used_colors[0]) cnt +=1;
                            if (cnt <3) begin
                                eligible1 =1;
                            end
                        end
                    end
                    if (eligible1) begin
                        if (end_val1 > best_end) begin
                            best_end = end_val1;
                            best_i =1;
                        end
                    end

                    int color_val2 = offers[2][11:10];
                    int start_val2 = offers[2][9:5];
                    int end_val2 = offers[2][4:0];
                    int eligible2 =0;
                    if (start_val2 <= current_position) begin
                        if ( (used_colors & (1 << color_val2)) !=0 ) begin
                            eligible2 =1;
                        end else begin
                            int cnt =0;
                            if (used_colors[3]) cnt +=1;
                            if (used_colors[2]) cnt +=1;
                            if (used_colors[1]) cnt +=1;
                            if (used_colors[0]) cnt +=1;
                            if (cnt <3) begin
                                eligible2 =1;
                            end
                        end
                    end
                    if (eligible2) begin
                        if (end_val2 > best_end) begin
                            best_end = end_val2;
                            best_i =2;
                        end
                    end

                    int color_val3 = offers[3][11:10];
                    int start_val3 = offers[3][9:5];
                    int end_val3 = offers[3][4:0];
                    int eligible3 =0;
                    if (start_val3 <= current_position) begin
                        if ( (used_colors & (1 << color_val3)) !=0 ) begin
                            eligible3 =1;
                        end else begin
                            int cnt =0;
                            if (used_colors[3]) cnt +=1;
                            if (used_colors[2]) cnt +=1;
                            if (used_colors[1]) cnt +=1;
                            if (used_colors[0]) cnt +=1;
                            if (cnt <3) begin
                                eligible3 =1;
                            end
                        end
                    end
                    if (eligible3) begin
                        if (end_val3 > best_end) begin
                            best_end = end_val3;
                            best_i =3;
                        end
                    end

                    if (best_i ==-1) begin
                        done <=1;
                        result <= offer_count;
                        possible <=0;
                        state <= DONE;
                    end else begin
                        int selected_end = offers[best_i][4:0];
                        int selected_color = offers[best_i][11:10];
                        current_position <= selected_end +1;
                        used_colors <= used_colors | (1 << selected_color);
                        offer_count <= offer_count +1;
                        if (current_position >16) begin
                            done <=1;
                            result <= offer_count;
                            possible <=1;
                            state <= DONE;
                        end
                    end
                end
            end
            DONE: begin
            end
        endcase
    end
endmodule
endmodule