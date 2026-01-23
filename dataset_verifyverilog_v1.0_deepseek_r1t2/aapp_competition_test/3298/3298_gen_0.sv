module unsorted_checker(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg done,
    output reg is_unsorted
);
    
    localparam [0:0] IDLE = 1'b0;
    localparam [0:0] COMPUTE = 1'b1;
    
    reg [0:0] state;
    reg is_unsorted_next;
    
    always @(*) begin
        reg [7:0] elements [0:7];
        reg found_sorted;
        integer k, j;
        reg left_ok, right_ok;
        
        // Map input ports to array
        elements[0] = arr_0;
        elements[1] = arr_1;
        elements[2] = arr_2;
        elements[3] = arr_3;
        elements[4] = arr_4;
        elements[5] = arr_5;
        elements[6] = arr_6;
        elements[7] = arr_7;
        
        found_sorted = 1'b0;
        
        for (k = 0; k < len; k = k + 1) begin
            left_ok = 1'b1;
            right_ok = 1'b1;
            
            // Check left elements
            for (j = 0; j < k; j = j + 1) begin
                if (elements[j] > elements[k]) begin
                    left_ok = 1'b0;
                end
            end
            
            // Check right elements
            for (j = k + 1; j < len; j = j + 1) begin
                if (elements[j] < elements[k]) begin
                    right_ok = 1'b0;
                end
            end
            
            if (left_ok && right_ok) begin
                found_sorted = 1'b1;
            end
        end
        
        is_unsorted_next = !found_sorted;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            is_unsorted <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    is_unsorted <= is_unsorted_next;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule