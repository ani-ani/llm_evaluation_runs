module StringSorter(
    input clk,
    input rst_n,
    input start,
    input [127:0] str_data,
    input [15:0] sublist_lens,
    output reg [127:0] result,
    output reg done
);

    // State declarations
    localparam [7:0] IDLE = 8'd0;
    localparam [7:0] SORT = 8'd1;
    localparam [7:0] OUTPUT = 8'd2;
    
    reg [7:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Sublist extraction and sorting
    reg [63:0] sublist_0 [0:3];
    reg [63:0] sublist_1 [0:3];
    reg [63:0] sublist_2 [0:3];
    reg [63:0] sublist_3 [0:3];
    
    reg [63:0] sorted_0 [0:3];
    reg [63:0] sorted_1 [0:3];
    reg [63:0] sorted_2 [0:3];
    reg [63:0] sorted_3 [0:3];

    // Insertion sort for each sublist
    always @(*) begin
        // Sublist 0
        integer i, j;
        reg [63:0] key;
        
        // Initialize sorted arrays
        for (i = 0; i < 4; i = i + 1) begin
            sorted_0[i] = sublist_0[i];
            sorted_1[i] = sublist_1[i];
            sorted_2[i] = sublist_2[i];
            sorted_3[i] = sublist_3[i];
        end
        
        // Sort sublist 0
        for (i = 1; i < 4; i = i + 1) begin
            if (sublist_0[i][7:0] < sorted_0[i-1][7:0]) begin
                key = sublist_0[i];
                j = i - 1;
                while (j >= 0 && sublist_0[j][7:0] > key[7:0]) begin
                    sorted_0[j+1] = sorted_0[j];
                    j = j - 1;
                end
                sorted_0[j+1] = key;
            end
        end
        
        // Sort sublist 1
        for (i = 1; i < 4; i = i + 1) begin
            if (sublist_1[i][7:0] < sorted_1[i-1][7:0]) begin
                key = sublist_1[i];
                j = i - 1;
                while (j >= 0 && sublist_1[j][7:0] > key[7:0]) begin
                    sorted_1[j+1] = sorted_1[j];
                    j = j - 1;
                end
                sorted_1[j+1] = key;
            end
        end
        
        // Sort sublist 2
        for (i = 1; i < 4; i = i + 1) begin
            if (sublist_2[i][7:0] < sorted_2[i-1][7:0]) begin
                key = sublist_2[i];
                j = i - 1;
                while (j >= 0 && sublist_2[j][7:0] > key[7:0]) begin
                    sorted_2[j+1] = sorted_2[j];
                    j = j - 1;
                end
                sorted_2[j+1] = key;
            end
        end
        
        // Sort sublist 3
        for (i = 1; i < 4; i = i + 1) begin
            if (sublist_3[i][7:0] < sorted_3[i-1][7:0]) begin
                key = sublist_3[i];
                j = i - 1;
                while (j >= 0 && sublist_3[j][7:0] > key[7:0]) begin
                    sorted_3[j+1] = sorted_3[j];
                    j = j - 1;
                end
                sorted_3[j+1] = key;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 128'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize sublists
            integer k;
            for (k = 0; k < 4; k = k + 1) begin
                sublist_0[k] <= 64'd0;
                sublist_1[k] <= 64'd0;
                sublist_2[k] <= 64'd0;
                sublist_3[k] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SORT;
                        
                        // Extract sublists from input
                        integer m;
                        for (m = 0; m < 4; m = m + 1) begin
                            sublist_0[m] <= str_data[m*64 +: 64];
                            sublist_1[m] <= str_data[4*64 + m*64 +: 64];
                            sublist_2[m] <= str_data[8*64 + m*64 +: 64];
                            sublist_3[m] <= str_data[12*64 + m*64 +: 64];
                        end
                    end
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Pack sorted strings into result
                    integer n;
                    for (n = 0; n < 4; n = n + 1) begin
                        result[n*64 +: 64] <= sorted_0[n];
                        result[4*64 + n*64 +: 64] <= sorted_1[n];
                        result[8*64 + n*64 +: 64] <= sorted_2[n];
                        result[12*64 + n*64 +: 64] <= sorted_3[n];
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule