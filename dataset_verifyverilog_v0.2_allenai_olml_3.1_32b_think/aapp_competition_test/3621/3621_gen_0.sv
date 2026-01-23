module monochromatic_clique_sum(input clk, input rst_n, input start, input [4:0] n, input [299:0] color_matrix [0:7][0:7], output reg [29:0] result, output reg done);
localparam integer MOD = 1000000007;

function integer count_bits(integer x);
    integer count;
    count =0;
    if (x & 1) count++;
    if (x & 2) count++;
    if (x &4) count++;
    if (x &8) count++;
    if (x &16) count++;
    return count;
endfunction

function [1:0] find_first_two_bits(integer x);
    integer first, second;
    first = -1;
    second = -1;
    if (x & 1) begin
        if (first == -1) first =0;
        else second =0;
    end else if (x &2) begin
        if (first ==-1) first =1;
        else second =1;
    end else if (x&4) begin
        if (first ==-1) first =2;
        else second =2;
    end else if (x&8) begin
        if (first ==-1) first =3;
        else second =3;
    end else if (x&16) begin
        if (first ==-1) first =4;
        else second =4;
    end
    if (second ==-1) return -2;
    return {first, second};
endfunction

function integer is_clique(integer sub, [299:0] color_matrix [0:7][0:7]);
    integer first_pair [1:0];
    first_pair = find_first_two_bits(sub);
    if (first_pair == -2) return 1;
    integer ref_color = color_matrix[first_pair[0]][first_pair[1]];
    for (integer i=0; i<5; i++) begin
        if (!(sub & (1<<i))) continue;
        for (integer j=i+1; j<5; j++) begin
            if (sub & (1<<j)) begin
                if (color_matrix[i][j] != ref_color) return 0;
            end
        end
    end
    return 1;
endfunction

integer max_size;
always @(*) begin
    if (done_reg || state == 0) 
        max_size =0;
    else begin
        max_size =0;
        integer sub;
        for (sub=1; sub <=31; sub++) begin
            if (sub > current_subset) continue;
            integer s_size = count_bits(sub);
            if (s_size <=2) begin
                if (s_size > max_size) max_size = s_size;
            end else begin
                if (is_clique(sub, color_matrix)) begin
                    if (s_size > max_size) max_size = s_size;
                end
            end
        end
    end
end

reg [2:0] state;
reg [4:0] current_subset;
reg [29:0] result_reg;
reg done_reg;
reg [31:0] max_size_reg;

wire [7:0] max_subset_w = (1 << n) -1;

always @(posedge clk) begin
    if (!rst_n) begin
        state <=0;
        current_subset <=0;
        result_reg <=0;
        done_reg <=0;
        max_size_reg <=0;
    end else begin
        case (state)
            0: // IDLE
                if (start) begin
                    state <=1; // ENUM
                    current_subset <=1;
                    done_reg <=0;
                end
            end
            1: // ENUM
                if (current_subset > max_subset_w) begin
                    state <=4; // DONE
                    done_reg <=1;
                end else begin
                    state <=2; // FIND
                end
            end
            2: // FIND
                state <=3; // SUM
            end
            3: // SUM
                max_size_reg <= max_size;
                result_reg <= (result_reg + max_size_reg) % MOD;
                current_subset <= current_subset +1;
                if (current_subset > max_subset_w) begin
                    state <=4;
                    done_reg <=1;
                end else begin
                    state <=1; // back to ENUM
                end
            end
            4: // DONE
            endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule