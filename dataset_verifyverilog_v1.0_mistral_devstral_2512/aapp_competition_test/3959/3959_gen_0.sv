module pokemon_evolution(
    input clk,
    input rst_n,
    input start,
    input [2:0] g1, g2,
    input [5:0] types1, types2,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Precompute factorials for 0,1,2,3
    function [15:0] factorial;
        input [1:0] n;
        begin
            case(n)
                2'd0: factorial = 1;
                2'd1: factorial = 1;
                2'd2: factorial = 2;
                2'd3: factorial = 6;
                default: factorial = 1;
            endcase
        end
    endfunction

    // Type encoding: 01=1, 10=2, 11=3
    wire [1:0] count_gym1_type1, count_gym1_type2, count_gym1_type3;
    wire [1:0] count_gym2_type1, count_gym2_type2, count_gym2_type3;

    // Count occurrences in gym1
    assign count_gym1_type1 = 
        (g1 >= 1 && types1[1:0] == 2'b01 ? 1 : 0) +
        (g1 >= 2 && types1[3:2] == 2'b01 ? 1 : 0) +
        (g1 >= 3 && types1[5:4] == 2'b01 ? 1 : 0);
    assign count_gym1_type2 = 
        (g1 >= 1 && types1[1:0] == 2'b10 ? 1 : 0) +
        (g1 >= 2 && types1[3:2] == 2'b10 ? 1 : 0) +
        (g1 >= 3 && types1[5:4] == 2'b10 ? 1 : 0);
    assign count_gym1_type3 = 
        (g1 >= 1 && types1[1:0] == 2'b11 ? 1 : 0) +
        (g1 >= 2 && types1[3:2] == 2'b11 ? 1 : 0) +
        (g1 >= 3 && types1[5:4] == 2'b11 ? 1 : 0);

    // Count occurrences in gym2
    assign count_gym2_type1 = 
        (g2 >= 1 && types2[1:0] == 2'b01 ? 1 : 0) +
        (g2 >= 2 && types2[3:2] == 2'b01 ? 1 : 0) +
        (g2 >= 3 && types2[5:4] == 2'b01 ? 1 : 0);
    assign count_gym2_type2 = 
        (g2 >= 1 && types2[1:0] == 2'b10 ? 1 : 0) +
        (g2 >= 2 && types2[3:2] == 2'b10 ? 1 : 0) +
        (g2 >= 3 && types2[5:4] == 2'b10 ? 1 : 0);
    assign count_gym2_type3 = 
        (g2 >= 1 && types2[1:0] == 2'b11 ? 1 : 0) +
        (g2 >= 2 && types2[3:2] == 2'b11 ? 1 : 0) +
        (g2 >= 3 && types2[5:4] == 2'b11 ? 1 : 0);

    // Form keys (4-bit: gym1 count, gym2 count)
    wire [3:0] key1 = {count_gym1_type1, count_gym2_type1};
    wire [3:0] key2 = {count_gym1_type2, count_gym2_type2};
    wire [3:0] key3 = {count_gym1_type3, count_gym2_type3};

    // Combinational grouping and product calculation
    reg [15:0] result_comb;
    always @(*) begin
        reg [1:0] group_count;
        reg [2:0] counted;
        reg [15:0] product;
        
        counted = 3'b000;
        product = 1;
        
        // Process type1
        if (!counted[0]) begin
            group_count = 1;
            counted[0] = 1;
            if (key2 == key1) begin
                group_count = group_count + 1;
                counted[1] = 1;
            end
            if (key3 == key1) begin
                group_count = group_count + 1;
                counted[2] = 1;
            end
            product = product * factorial(group_count);
        end
        
        // Process type2
        if (!counted[1]) begin
            group_count = 1;
            counted[1] = 1;
            if (key3 == key2) begin
                group_count = group_count + 1;
                counted[2] = 1;
            end
            product = product * factorial(group_count);
        end
        
        // Process type3
        if (!counted[2]) begin
            group_count = 1;
            product = product * factorial(group_count);
        end
        
        result_comb = product;
    end

    // Sequential output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= result_comb;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule