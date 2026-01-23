module tuple_intersection (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input tuples: 2 elements of 8 bits each
    // We receive 4 tuples from test_list1 and 4 from test_list2
    input wire [7:0] list1_a_0, list1_b_0,
    input wire [7:0] list1_a_1, list1_b_1,
    input wire [7:0] list1_a_2, list1_b_2,
    input wire [7:0] list1_a_3, list1_b_3,
    
    input wire [7:0] list2_a_0, list2_b_0,
    input wire [7:0] list2_a_1, list2_b_1,
    input wire [7:0] list2_a_2, list2_b_2,
    input wire [7:0] list2_a_3, list2_b_3,
    
    // Number of valid tuples in each list (1-4)
    input wire [2:0] len1,
    input wire [2:0] len2,
    
    // Output matches: up to 4 matches
    // Each match is a normalized tuple (min, max)
    output reg [7:0] match_a_0, match_b_0,
    output reg [7:0] match_a_1, match_b_1,
    output reg [7:0] match_a_2, match_b_2,
    output reg [7:0] match_a_3, match_b_3,
    output reg [2:0] match_count,
    
    output reg done
);

    // State machine states
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] NORMALIZE_LIST1 = 3'd1;
    localparam [2:0] SEARCH_LIST2  = 3'd2;
    localparam [2:0] FINISH        = 3'd3;

    reg [2:0] state;
    reg [2:0] idx1;
    reg [2:0] idx2;
    reg [2:0] match_idx;
    reg [2:0] temp_match_count;
    
    // Storage for normalized list1
    reg [7:0] norm1_a [0:3];
    reg [7:0] norm1_b [0:3];
    reg valid1 [0:3];
    
    // Temporary storage
    reg [7:0] temp_a;
    reg [7:0] temp_b;
    reg [7:0] norm_temp_a;
    reg [7:0] norm_temp_b;
    
    // Match buffer for current comparison
    reg [2:0] match_check_idx;
    reg match_found;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            match_count <= 3'd0;
            idx1 <= 3'd0;
            idx2 <= 3'd0;
            match_idx <= 3'd0;
            temp_match_count <= 3'd0;
            match_check_idx <= 3'd0;
            match_found <= 1'b0;
            temp_a <= 8'd0;
            temp_b <= 8'd0;
            norm_temp_a <= 8'd0;
            norm_temp_b <= 8'd0;
            
            for (i = 0; i < 4; i = i + 1) begin
                valid1[i] <= 1'b0;
                norm1_a[i] <= 8'd0;
                norm1_b[i] <= 8'd0;
            end
            
            match_a_0 <= 8'd0; match_b_0 <= 8'd0;
            match_a_1 <= 8'd0; match_b_1 <= 8'd0;
            match_a_2 <= 8'd0; match_b_2 <= 8'd0;
            match_a_3 <= 8'd0; match_b_3 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match_count <= 3'd0;
                    idx1 <= 3'd0;
                    idx2 <= 3'd0;
                    match_idx <= 3'd0;
                    temp_match_count <= 3'd0;
                    match_check_idx <= 3'd0;
                    match_found <= 1'b0;
                    
                    for (i = 0; i < 4; i = i + 1) begin
                        valid1[i] <= 1'b0;
                    end
                    
                    if (start) begin
                        state <= NORMALIZE_LIST1;
                    end
                end
                
                NORMALIZE_LIST1: begin
                    if (idx1 < len1 && idx1 < 4) begin
                        // Get current tuple
                        case (idx1)
                            3'd0: begin temp_a <= list1_a_0; temp_b <= list1_b_0; end
                            3'd1: begin temp_a <= list1_a_1; temp_b <= list1_b_1; end
                            3'd2: begin temp_a <= list1_a_2; temp_b <= list1_b_2; end
                            3'd3: begin temp_a <= list1_a_3; temp_b <= list1_b_3; end
                        endcase
                        
                        // Normalize (ensure a <= b)
                        if (temp_a <= temp_b) begin
                            norm1_a[idx1] <= temp_a;
                            norm1_b[idx1] <= temp_b;
                        end else begin
                            norm1_a[idx1] <= temp_b;
                            norm1_b[idx1] <= temp_a;
                        end
                        valid1[idx1] <= 1'b1;
                        idx1 <= idx1 + 3'd1;
                    end else begin
                        state <= SEARCH_LIST2;
                        idx2 <= 3'd0;
                    end
                end
                
                SEARCH_LIST2: begin
                    if (idx2 < len2 && idx2 < 4) begin
                        // Get current tuple from list2
                        case (idx2)
                            3'd0: begin temp_a <= list2_a_0; temp_b <= list2_b_0; end
                            3'd1: begin temp_a <= list2_a_1; temp_b <= list2_b_1; end
                            3'd2: begin temp_a <= list2_a_2; temp_b <= list2_b_2; end
                            3'd3: begin temp_a <= list2_a_3; temp_b <= list2_b_3; end
                        endcase
                        
                        // Normalize list2 tuple for comparison
                        if (list2_a_0 <= list2_b_0 && idx2 == 3'd0) begin norm_temp_a <= list2_a_0; norm_temp_b <= list2_b_0; end
                        else if (list2_a_0 > list2_b_0 && idx2 == 3'd0) begin norm_temp_a <= list2_b_0; norm_temp_b <= list2_a_0; end
                        else if (list2_a_1 <= list2_b_1 && idx2 == 3'd1) begin norm_temp_a <= list2_a_1; norm_temp_b <= list2_b_1; end
                        else if (list2_a_1 > list2_b_1 && idx2 == 3'd1) begin norm_temp_a <= list2_b_1; norm_temp_b <= list2_a_1; end
                        else if (list2_a_2 <= list2_b_2 && idx2 == 3'd2) begin norm_temp_a <= list2_a_2; norm_temp_b <= list2_b_2; end
                        else if (list2_a_2 > list2_b_2 && idx2 == 3'd2) begin norm_temp_a <= list2_b_2; norm_temp_b <= list2_a_2; end
                        else if (list2_a_3 <= list2_b_3 && idx2 == 3'd3) begin norm_temp_a <= list2_a_3; norm_temp_b <= list2_b_3; end
                        else if (list2_a_3 > list2_b_3 && idx2 == 3'd3) begin norm_temp_a <= list2_b_3; norm_temp_b <= list2_a_3; end
                        else begin norm_temp_a <= list2_a_0; norm_temp_b <= list2_b_0; end
                        
                        match_check_idx <= 3'd0;
                        match_found <= 1'b0;
                        
                        // Check if current list2 tuple matches any list1 tuple
                        // Use comb logic directly
                        if (valid1[0] && norm1_a[0] == norm_temp_a && norm1_b[0] == norm_temp_b) begin
                            if (match_idx < 4) begin
                                match_a_0 <= norm_temp_a; match_b_0 <= norm_temp_b;
                                match_idx <= match_idx + 3'd1;
                                temp_match_count <= temp_match_count + 3'd1;
                            end
                        end
                        else if (valid1[1] && norm1_a[1] == norm_temp_a && norm1_b[1] == norm_temp_b) begin
                            if (match_idx < 4) begin
                                match_a_1 <= norm_temp_a; match_b_1 <= norm_temp_b;
                                match_idx <= match_idx + 3'd1;
                                temp_match_count <= temp_match_count + 3'd1;
                            end
                        end
                        else if (valid1[2] && norm1_a[2] == norm_temp_a && norm1_b[2] == norm_temp_b) begin
                            if (match_idx < 4) begin
                                match_a_2 <= norm_temp_a; match_b_2 <= norm_temp_b;
                                match_idx <= match_idx + 3'd1;
                                temp_match_count <= temp_match_count + 3'd1;
                            end
                        end
                        else if (valid1[3] && norm1_a[3] == norm_temp_a && norm1_b[3] == norm_temp_b) begin
                            if (match_idx < 4) begin
                                match_a_3 <= norm_temp_a; match_b_3 <= norm_temp_b;
                                match_idx <= match_idx + 3'd1;
                                temp_match_count <= temp_match_count + 3'd1;
                            end
                        end
                        
                        idx2 <= idx2 + 3'd1;
                    end else begin
                        match_count <= temp_match_count;
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