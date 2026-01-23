module large_product (input clk, input rst_n, input start, input [2:0] N, input [2:0] size1, input [2:0] size2, input [7:0] list1 [0:7], input [7:0] list2 [0:7], output reg [15:0] result [0:7], output reg [3:0] valid_count, output reg done);
reg [2:0] state;
reg [15:0] products [0:63];
reg [6:0] prod_count;
reg [2:0] i, j;
reg [6:0] bubble_pass;
reg [6:0] bubble_index;
reg swap_occurred;
reg [15:0] temp;
reg [3:0] k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 0;
        prod_count <= 0;
        i <= 0; j <= 0;
        bubble_pass <= 0; bubble_index <= 0; swap_occurred <= 0; temp <= 0;
        k <= 0;
        result <= {8{16'b0}};
        valid_count <= 4'd0;
        done <= 1'b0;
    end else begin
        case (state)
            0: begin
                if (start) begin
                    state <= 1;
                    i <= 0;
                    j <= 0;
                    prod_count <= 0;
                end
            end
            1: begin
                if (i < size1) begin
                    if (j < size2) begin
                        products[prod_count] = list1[i] * list2[j];
                        prod_count <= prod_count + 1;
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end else begin
                    state <= 2;
                    bubble_pass <= 0;
                    bubble_index <= 0;
                    swap_occurred <= 1;
                end
            end
            2: begin
                if (bubble_index < prod_count - 1) begin
                    if (products[bubble_index] < products[bubble_index + 1]) begin
                        temp = products[bubble_index];
                        products[bubble_index] = products[bubble_index + 1];
                        products[bubble_index + 1] = temp;
                        swap_occurred = 1;
                    end
                    bubble_index <= bubble_index + 1;
                end else begin
                    if (swap_occurred) begin
                        bubble_pass <= bubble_pass + 1;
                        if (bubble_pass < prod_count) begin
                            bubble_index <= 0;
                            swap_occurred <= 0;
                        end else begin
                            state <= 3;
                            k <= 0;
                        end
                    end else begin
                        state <= 3;
                        k <= 0;
                    end
                end
            end
            3: begin
                if (k < N && k < prod_count) begin
                    result[k] = products[k];
                    k <= k + 1;
                end else begin
                    valid_count = (N < prod_count) ? N : prod_count;
                    state <= 4;
                end
            end
            4: begin
                done = 1'b1;
            end
        endcase
    end
endmodule