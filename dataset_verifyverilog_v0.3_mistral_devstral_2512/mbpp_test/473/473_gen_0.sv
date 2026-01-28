module tuple_intersection (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input tuples: 2 elements of 8 bits each
    // We receive 4 tuples from test_list1 and 4 from test_list2
    // Using individual ports for inputs
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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] NORMALIZE_LIST1 = 2'd1;
    localparam [1:0] SEARCH_LIST2 = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [2:0] idx1;
    reg [2:0] idx2;
    reg [2:0] match_idx;
    
    // Storage for normalized list1
    reg [7:0] norm1_a [0:3];
    reg [7:0] norm1_b [0:3];
    reg valid1 [0:3];
    
    // Temporary normalization
    reg [7:0] temp_a, temp_b;
    reg [7:0] cur_a, cur_b;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            match_count <= 3'd0;
            idx1 <= 3'd0;
            idx2 <= 3'd0;
            match_idx <= 3'd0;
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
                    if (start) begin
                        state <= NORMALIZE_LIST1;
                        idx1 <= 3'd0;
                        match_count <= 3'd0;
                        match_idx <= 3'd0;
                    end
                end
                
                NORMALIZE_LIST1: begin
                    if (idx1 < len1 && idx1 < 4) begin
                        // Normalize current tuple (swap if needed)
                        case (idx1)
                            3'd0: begin cur_a <= list1_a_0; cur_b <= list1_b_0; end
                            3'd1: begin cur_a <= list1_a_1; cur_b <= list1_b_1; end
                            3'd2: begin cur_a <= list1_a_2; cur_b <= list1_b_2; end
                            3'd3: begin cur_a <= list1_a_3; cur_b <= list1_b_3; end
                        endcase
                        
                        // Store normalized (min, max)
                        if (cur_a <= cur_b) begin
                            norm1_a[idx1] <= cur_a;
                            norm1_b[idx1] <= cur_b;
                        end else begin
                            norm1_a[idx1] <= cur_b;
                            norm1_b[idx1] <= cur_a;
                        end
                        valid1[idx1] <= 1'b1;
                        idx1 <= idx1 + 3'd1;
                    end else begin
                        state <= SEARCH_LIST2;
                        idx1 <= 3'd0;
                        idx2 <= 3'd0;
                    end
                end
                
                SEARCH_LIST2: begin
                    if (idx2 < len2 && idx2 < 4) begin
                        // Get and normalize current list2 tuple
                        case (idx2)
                            3'd0: begin temp_a <= list2_a_0; temp_b <= list2_b_0; end
                            3'd1: begin temp_a <= list2_a_1; temp_b <= list2_b_1; end
                            3'd2: begin temp_a <= list2_a_2; temp_b <= list2_b_2; end
                            3'd3: begin temp_a <= list2_a_3; temp_b <= list2_b_3; end
                        endcase
                        
                        // Normalize for comparison
                        if (temp_a <= temp_b) begin
                            cur_a <= temp_a;
                            cur_b <= temp_b;
                        end else begin
                            cur_a <= temp_b;
                            cur_b <= temp_a;
                        end
                        
                        // Check match with all valid list1 tuples
                        if (valid1[0] && norm1_a[0] == cur_a && norm1_b[0] == cur_b) begin
                            if (match_idx < 4) begin
                                case (match_idx)
                                    3'd0: begin match_a_0 <= cur_a; match_b_0 <= cur_b; end
                                    3'd1: begin match_a_1 <= cur_a; match_b_1 <= cur_b; end
                                    3'd2: begin match_a_2 <= cur_a; match_b_2 <= cur_b; end
                                    3'd3: begin match_a_3 <= cur_a; match_b_3 <= cur_b; end
                                endcase
                                match_idx <= match_idx + 3'd1;
                                match_count <= match_count + 3'd1;
                            end
                        end else if (valid1[1] && norm1_a[1] == cur_a && norm1_b[1] == cur_b) begin
                            if (match_idx < 4) begin
                                case (match_idx)
                                    3'd0: begin match_a_0 <= cur_a; match_b_0 <= cur_b; end
                                    3'd1: begin match_a_1 <= cur_a; match_b_1 <= cur_b; end
                                    3'd2: begin match_a_2 <= cur_a; match_b_2 <= cur_b; end
                                    3'd3: begin match_a_3 <= cur_a; match_b_3 <= cur_b; end
                                endcase
                                match_idx <= match_idx + 3'd1;
                                match_count <= match_count + 3'd1;
                            end
                        end else if (valid1[2] && norm1_a[2] == cur_a && norm1_b[2] == cur_b) begin
                            if (match_idx < 4) begin
                                case (match_idx)
                                    3'd0: begin match_a_0 <= cur_a; match_b_0 <= cur_b; end
                                    3'd1: begin match_a_1 <= cur_a; match_b_1 <= cur_b; end
                                    3'd2: begin match_a_2 <= cur_a; match_b_2 <= cur_b; end
                                    3'd3: begin match_a_3 <= cur_a; match_b_3 <= cur_b; end
                                endcase
                                match_idx <= match_idx + 3'd1;
                                match_count <= match_count + 3'd1;
                            end
                        end else if (valid1[3] && norm1_a[3] == cur_a && norm1_b[3] == cur_b) begin
                            if (match_idx < 4) begin
                                case (match_idx)
                                    3'd0: begin match_a_0 <= cur_a; match_b_0 <= cur_b; end
                                    3'd1: begin match_a_1 <= cur_a; match_b_1 <= cur_b; end
                                    3'd2: begin match_a_2 <= cur_a; match_b_2 <= cur_b; end
                                    3'd3: begin match_a_3 <= cur_a; match_b_3 <= cur_b; end
                                endcase
                                match_idx <= match_idx + 3'd1;
                                match_count <= match_count + 3'd1;
                            end
                        end
                        
                        idx2 <= idx2 + 3'd1;
                    end else begin
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