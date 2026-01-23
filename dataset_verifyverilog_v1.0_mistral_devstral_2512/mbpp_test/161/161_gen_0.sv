module remove_elements(
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [3:0] len1,
    input [3:0] len2,
    output [7:0] result [0:7],
    output [3:0] result_len
);

    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg [7:0] current_element;
    reg match_found;
    reg [3:0] count;

    always @(*) begin
        count = 4'd0;
        k = 4'd0;
        
        for (i = 0; i < 8; i = i + 1) begin
            if (i < len1) begin
                current_element = list1[i];
                match_found = 1'b0;
                
                for (j = 0; j < 8; j = j + 1) begin
                    if (j < len2 && list2[j] == current_element) begin
                        match_found = 1'b1;
                    end
                end
                
                if (!match_found) begin
                    result[k] = current_element;
                    k = k + 4'd1;
                end
            end
        end
        
        result_len = k;
    end

endmodule