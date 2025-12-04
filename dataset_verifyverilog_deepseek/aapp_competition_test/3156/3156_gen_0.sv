module store_path_detector(
    input clk,
    input rst_n,
    input start,
    input [1:0] num_stores,
    input [3:0][1:0] store_ids,
    input [3:0][1:0] item_ids,
    input [3:0][1:0] bought_list,
    input [1:0] num_bought,
    output reg [1:0] result,
    output reg done
);

    reg [3:0][3:0] item_available;
    reg [3:0][1:0] bought_list_reg;
    reg [1:0] num_bought_reg;
    reg [3:0] path_state_v;
    reg [3:0] path_state_m;
    reg [2:0] cycle_counter;
    reg processing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            result <= 0;
            item_available <= 0;
            bought_list_reg <= 0;
            num_bought_reg <= 0;
            path_state_v <= 0;
            path_state_m <= 0;
            cycle_counter <= 0;
            processing <= 0;
        end else begin
            done <= 0;

            if (start) begin
                item_available <= 0;
                if (num_stores > 0) item_available[item_ids[0]][store_ids[0]] <= 1'b1;
                if (num_stores > 1) item_available[item_ids[1]][store_ids[1]] <= 1'b1;
                if (num_stores > 2) item_available[item_ids[2]][store_ids[2]] <= 1'b1;
                if (num_stores > 3) item_available[item_ids[3]][store_ids[3]] <= 1'b1;

                bought_list_reg <= bought_list;
                num_bought_reg <= num_bought;
                
                path_state_v <= 0;
                path_state_m <= 0;
                if (num_bought != 0) begin
                    if (item_available[bought_list[0]][0]) path_state_v[0] <= 1'b1;
                    if (item_available[bought_list[0]][1]) path_state_v[1] <= 1'b1;
                    if (item_available[bought_list[0]][2]) path_state_v[2] <= 1'b1;
                    if (item_available[bought_list[0]][3]) path_state_v[3] <= 1'b1;
                end
                
                cycle_counter <= 0;
                processing <= 1'b1;
            end else if (processing) begin
                cycle_counter <= cycle_counter + 1;

                if (cycle_counter < num_bought_reg) begin
                    reg [1:0] current_item = bought_list_reg[cycle_counter];
                    reg [3:0] new_v;
                    reg [3:0] new_m;

                    // Store 0
                    begin
                        reg pre_sum = path_state_v[0] | path_state_m[0];
                        reg pre_any_multi = path_state_m[0];
                        reg [1:0] pre_count_v = path_state_v[0] & ~path_state_m[0];
                        new_v[0] = item_available[current_item][0] & pre_sum;
                        new_m[0] = new_v[0] & ((pre_count_v >= 2) | pre_any_multi);
                    end

                    // Store 1
                    begin
                        reg pre_sum = (path_state_v[0] | path_state_m[0]) | (path_state_v[1] | path_state_m[1]);
                        reg pre_any_multi = path_state_m[0] | path_state_m[1];
                        reg [1:0] pre_count_v = (path_state_v[0] & ~path_state_m[0]) + (path_state_v[1] & ~path_state_m[1]);
                        new_v[1] = item_available[current_item][1] & pre_any;
                        new_m[1] = new_v[1] & ((pre_count_v >= 2) | pre_any_multi);
                    end

                    // Store 2
                    begin
                        reg pre_sum = (path_state_v[0] | path_state_m[0]) | (path_state_v[1] | path_state_m[1]) | (path_state_v[2] | path_state_m[2]);
                        reg pre_any_multi = path_state_m[0] | path_state_m[1] | path_state_m[2];
                        reg [1:0] pre_count_v = (path_state_v[0] & ~path_state_m[0]) + (path_state_v[1] & ~path_state_m[1]) + (path_state_v[2] & ~path_state_m[2]);
                        new_v[2] = item_available[current_item][2] & pre_sum;
                        new_m[2] = new_v[2] & ((pre_count_v >= 2) | pre_any_multi);
                    end

                    // Store 3
                    begin
                        reg pre_sum = (path_state_v[0] | path_state_m[0]) | (path_state_v[1] | path_state_m[1]) | (path_state_v[2] | path_state_m[2]) | (path_state_v[3] | path_state_m[3]);
                        reg pre_any_multi = path_state_m[0] | path_state_m[1] | path_state_m[2] | path_state_m[3];
                        reg [1:0] pre_count_v = (path_state_v[0] & ~path_state_m[0]) + (path_state_v[1] & ~path_state_m[1]) + (path_state_v[2] & ~path_state_m[2]) + (path_state_v[3] & ~path_state_m[3]);
                        new_v[3] = item_available[current_item][3] & pre_sum;
                        new_m[3] = new_v[3] & ((pre_count_v >= 2) | pre_any_multi);
                    end

                    path_state_v <= new_v;
                    path_state_m <= new_m;
                end

                if (cycle_counter == num_bought_reg) begin
                    if (|path_state_m) begin
                        result <= 2'b10;
                    end else begin
                        reg [1:0] count = 0;
                        if (path_state_v[0] & ~path_state_m[0]) count += 1;
                        if (path_state_v[1] & ~path_state_m[1]) count += 1;
                        if (path_state_v[2] & ~path_state_m[2]) count += 1;
                        if (path_state_v[3] & ~path_state_m[3]) count += 1;
                        
                        case(count)
                            0: result <= 2'b00;
                            1: result <= 2'b01;
                            default: result <= 2'b10;
                        endcase
                    end
                end
                
                if (cycle_counter == num_bought_reg + 1) begin
                    done <= 1'b1;
                    processing <= 1'b0;
                end
            end
        end
    end
endmodule