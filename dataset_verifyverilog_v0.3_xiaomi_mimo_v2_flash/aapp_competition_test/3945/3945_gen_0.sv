module cell_answer (
    input [7:0] matrix00, matrix01, matrix02, matrix03,
    input [7:0] matrix10, matrix11, matrix12, matrix13,
    input [7:0] matrix20, matrix21, matrix22, matrix23,
    input [7:0] matrix30, matrix31, matrix32, matrix33,
    output [7:0] answer00, answer01, answer02, answer03,
    output [7:0] answer10, answer11, answer12, answer13,
    output [7:0] answer20, answer21, answer22, answer23,
    output [7:0] answer30, answer31, answer32, answer33
);

// Sorting function for 4 elements
function automatic [7:0] sort_element(input [7:0] arr0, arr1, arr2, arr3, input integer idx);
    // Use intermediate sorted values from sorting network
    wire [7:0] t0, t1, t2, t3;
    wire [7:0] u0, u1, u2, u3;
    wire [7:0] s0, s1, s2, s3;
    
    // Step 1: Compare pairs
    assign t0 = (arr0 < arr1) ? arr0 : arr1;
    assign t1 = (arr0 < arr1) ? arr1 : arr0;
    assign t2 = (arr2 < arr3) ? arr2 : arr3;
    assign t3 = (arr2 < arr3) ? arr3 : arr2;
    
    // Step 2: Compare cross pairs
    assign u0 = (t0 < t2) ? t0 : t2;
    assign u2 = (t0 < t2) ? t2 : t0;
    assign u1 = (t1 < t3) ? t1 : t3;
    assign u3 = (t1 < t3) ? t3 : t1;
    
    // Step 3: Final sort of middle pair
    assign s0 = u0;
    assign s1 = (u1 < u2) ? u1 : u2;
    assign s2 = (u1 < u2) ? u2 : u1;
    assign s3 = u3;
    
    // Return element at index
    case (idx)
        2'd0: sort_element = s0;
        2'd1: sort_element = s1;
        2'd2: sort_element = s2;
        2'd3: sort_element = s3;
        default: sort_element = 8'd0;
    endcase
endfunction

// Rank function: returns rank of value in sorted unique array
function automatic [1:0] compute_rank(input [7:0] value, input [7:0] s0, s1, s2, s3);
    // Check uniqueness and count elements less than value
    wire u0_valid = 1'b1;
    wire u1_valid = (s1 != s0);
    wire u2_valid = (s2 != s1);
    wire u3_valid = (s3 != s2);
    
    compute_rank = 2'd0;
    if (u0_valid && s0 < value) compute_rank = compute_rank + 2'd1;
    if (u1_valid && s1 < value) compute_rank = compute_rank + 2'd1;
    if (u2_valid && s2 < value) compute_rank = compute_rank + 2'd1;
    if (u3_valid && s3 < value) compute_rank = compute_rank + 2'd1;
endfunction

// Unique count function
function automatic [1:0] unique_count(input [7:0] s0, s1, s2, s3);
    wire u0_valid = 1'b1;
    wire u1_valid = (s1 != s0);
    wire u2_valid = (s2 != s1);
    wire u3_valid = (s3 != s2);
    unique_count = u0_valid + u1_valid + u2_valid + u3_valid;
endfunction

// Sort rows
wire [7:0] row0_sorted0, row0_sorted1, row0_sorted2, row0_sorted3;
wire [7:0] row1_sorted0, row1_sorted1, row1_sorted2, row1_sorted3;
wire [7:0] row2_sorted0, row2_sorted1, row2_sorted2, row2_sorted3;
wire [7:0] row3_sorted0, row3_sorted1, row3_sorted2, row3_sorted3;

assign row0_sorted0 = sort_element(matrix00, matrix01, matrix02, matrix03, 0);
assign row0_sorted1 = sort_element(matrix00, matrix01, matrix02, matrix03, 1);
assign row0_sorted2 = sort_element(matrix00, matrix01, matrix02, matrix03, 2);
assign row0_sorted3 = sort_element(matrix00, matrix01, matrix02, matrix03, 3);

assign row1_sorted0 = sort_element(matrix10, matrix11, matrix12, matrix13, 0);
assign row1_sorted1 = sort_element(matrix10, matrix11, matrix12, matrix13, 1);
assign row1_sorted2 = sort_element(matrix10, matrix11, matrix12, matrix13, 2);
assign row1_sorted3 = sort_element(matrix10, matrix11, matrix12, matrix13, 3);

assign row2_sorted0 = sort_element(matrix20, matrix21, matrix22, matrix23, 0);
assign row2_sorted1 = sort_element(matrix20, matrix21, matrix22, matrix23, 1);
assign row2_sorted2 = sort_element(matrix20, matrix21, matrix22, matrix23, 2);
assign row2_sorted3 = sort_element(matrix20, matrix21, matrix22, matrix23, 3);

assign row3_sorted0 = sort_element(matrix30, matrix31, matrix32, matrix33, 0);
assign row3_sorted1 = sort_element(matrix30, matrix31, matrix32, matrix33, 1);
assign row3_sorted2 = sort_element(matrix30, matrix31, matrix32, matrix33, 2);
assign row3_sorted3 = sort_element(matrix30, matrix31, matrix32, matrix33, 3);

// Sort columns
wire [7:0] col0_sorted0, col0_sorted1, col0_sorted2, col0_sorted3;
wire [7:0] col1_sorted0, col1_sorted1, col1_sorted2, col1_sorted3;
wire [7:0] col2_sorted0, col2_sorted1, col2_sorted2, col2_sorted3;
wire [7:0] col3_sorted0, col3_sorted1, col3_sorted2, col3_sorted3;

assign col0_sorted0 = sort_element(matrix00, matrix10, matrix20, matrix30, 0);
assign col0_sorted1 = sort_element(matrix00, matrix10, matrix20, matrix30, 1);
assign col0_sorted2 = sort_element(matrix00, matrix10, matrix20, matrix30, 2);
assign col0_sorted3 = sort_element(matrix00, matrix10, matrix20, matrix30, 3);

assign col1_sorted0 = sort_element(matrix01, matrix11, matrix21, matrix31, 0);
assign col1_sorted1 = sort_element(matrix01, matrix11, matrix21, matrix31, 1);
assign col1_sorted2 = sort_element(matrix01, matrix11, matrix21, matrix31, 2);
assign col1_sorted3 = sort_element(matrix01, matrix11, matrix21, matrix31, 3);

assign col2_sorted0 = sort_element(matrix02, matrix12, matrix22, matrix32, 0);
assign col2_sorted1 = sort_element(matrix02, matrix12, matrix22, matrix32, 1);
assign col2_sorted2 = sort_element(matrix02, matrix12, matrix22, matrix32, 2);
assign col2_sorted3 = sort_element(matrix02, matrix12, matrix22, matrix32, 3);

assign col3_sorted0 = sort_element(matrix03, matrix13, matrix23, matrix33, 0);
assign col3_sorted1 = sort_element(matrix03, matrix13, matrix23, matrix33, 1);
assign col3_sorted2 = sort_element(matrix03, matrix13, matrix23, matrix33, 2);
assign col3_sorted3 = sort_element(matrix03, matrix13, matrix23, matrix33, 3);

// Compute row and column statistics
wire [1:0] u_row0 = unique_count(row0_sorted0, row0_sorted1, row0_sorted2, row0_sorted3);
wire [1:0] u_row1 = unique_count(row1_sorted0, row1_sorted1, row1_sorted2, row1_sorted3);
wire [1:0] u_row2 = unique_count(row2_sorted0, row2_sorted1, row2_sorted2, row2_sorted3);
wire [1:0] u_row3 = unique_count(row3_sorted0, row3_sorted1, row3_sorted2, row3_sorted3);

wire [1:0] u_col0 = unique_count(col0_sorted0, col0_sorted1, col0_sorted2, col0_sorted3);
wire [1:0] u_col1 = unique_count(col1_sorted0, col1_sorted1, col1_sorted2, col1_sorted3);
wire [1:0] u_col2 = unique_count(col2_sorted0, col2_sorted1, col2_sorted2, col2_sorted3);
wire [1:0] u_col3 = unique_count(col3_sorted0, col3_sorted1, col3_sorted2, col3_sorted3);

// Compute ranks for each element
wire [1:0] rank_row00 = compute_rank(matrix00, row0_sorted0, row0_sorted1, row0_sorted2, row0_sorted3);
wire [1:0] rank_row01 = compute_rank(matrix01, row0_sorted0, row0_sorted1, row0_sorted2, row0_sorted3);
wire [1:0] rank_row02 = compute_rank(matrix02, row0_sorted0, row0_sorted1, row0_sorted2, row0_sorted3);
wire [1:0] rank_row03 = compute_rank(matrix03, row0_sorted0, row0_sorted1, row0_sorted2, row0_sorted3);

wire [1:0] rank_row10 = compute_rank(matrix10, row1_sorted0, row1_sorted1, row1_sorted2, row1_sorted3);
wire [1:0] rank_row11 = compute_rank(matrix11, row1_sorted0, row1_sorted1, row1_sorted2, row1_sorted3);
wire [1:0] rank_row12 = compute_rank(matrix12, row1_sorted0, row1_sorted1, row1_sorted2, row1_sorted3);
wire [1:0] rank_row13 = compute_rank(matrix13, row1_sorted0, row1_sorted1, row1_sorted2, row1_sorted3);

wire [1:0] rank_row20 = compute_rank(matrix20, row2_sorted0, row2_sorted1, row2_sorted2, row2_sorted3);
wire [1:0] rank_row21 = compute_rank(matrix21, row2_sorted0, row2_sorted1, row2_sorted2, row2_sorted3);
wire [1:0] rank_row22 = compute_rank(matrix22, row2_sorted0, row2_sorted1, row2_sorted2, row2_sorted3);
wire [1:0] rank_row23 = compute_rank(matrix23, row2_sorted0, row2_sorted1, row2_sorted2, row2_sorted3);

wire [1:0] rank_row30 = compute_rank(matrix30, row3_sorted0, row3_sorted1, row3_sorted2, row3_sorted3);
wire [1:0] rank_row31 = compute_rank(matrix31, row3_sorted0, row3_sorted1, row3_sorted2, row3_sorted3);
wire [1:0] rank_row32 = compute_rank(matrix32, row3_sorted0, row3_sorted1, row3_sorted2, row3_sorted3);
wire [1:0] rank_row33 = compute_rank(matrix33, row3_sorted0, row3_sorted1, row3_sorted2, row3_sorted3);

wire [1:0] rank_col00 = compute_rank(matrix00, col0_sorted0, col0_sorted1, col0_sorted2, col0_sorted3);
wire [1:0] rank_col01 = compute_rank(matrix01, col1_sorted0, col1_sorted1, col1_sorted2, col1_sorted3);
wire [1:0] rank_col02 = compute_rank(matrix02, col2_sorted0, col2_sorted1, col2_sorted2, col2_sorted3);
wire [1:0] rank_col03 = compute_rank(matrix03, col3_sorted0, col3_sorted1, col3_sorted2, col3_sorted3);

wire [1:0] rank_col10 = compute_rank(matrix10, col0_sorted0, col0_sorted1, col0_sorted2, col0_sorted3);
wire [1:0] rank_col11 = compute_rank(matrix11, col1_sorted0, col1_sorted1, col1_sorted2, col1_sorted3);
wire [1:0] rank_col12 = compute_rank(matrix12, col2_sorted0, col2_sorted1, col2_sorted2, col2_sorted3);
wire [1:0] rank_col13 = compute_rank(matrix13, col3_sorted0, col3_sorted1, col3_sorted2, col3_sorted3);

wire [1:0] rank_col20 = compute_rank(matrix20, col0_sorted0, col0_sorted1, col0_sorted2, col0_sorted3);
wire [1:0] rank_col21 = compute_rank(matrix21, col1_sorted0, col1_sorted1, col1_sorted2, col1_sorted3);
wire [1:0] rank_col22 = compute_rank(matrix22, col2_sorted0, col2_sorted1, col2_sorted2, col2_sorted3);
wire [1:0] rank_col23 = compute_rank(matrix23, col3_sorted0, col3_sorted1, col3_sorted2, col3_sorted3);

wire [1:0] rank_col30 = compute_rank(matrix30, col0_sorted0, col0_sorted1, col0_sorted2, col0_sorted3);
wire [1:0] rank_col31 = compute_rank(matrix31, col1_sorted0, col1_sorted1, col1_sorted2, col1_sorted3);
wire [1:0] rank_col32 = compute_rank(matrix32, col2_sorted0, col2_sorted1, col2_sorted2, col2_sorted3);
wire [1:0] rank_col33 = compute_rank(matrix33, col3_sorted0, col3_sorted1, col3_sorted2, col3_sorted3);

// Compute final answer for each cell
// For cell (i,j), result = max(row_rank, col_rank) + max(u_row - row_rank, u_col - col_rank)

wire [1:0] max_row00 = (rank_row00 > rank_col00) ? rank_row00 : rank_col00;
wire [1:0] diff_row00 = u_row0 - rank_row00;
wire [1:0] diff_col00 = u_col0 - rank_col00;
wire [1:0] max_diff00 = (diff_row00 > diff_col00) ? diff_row00 : diff_col00;
assign answer00 = {6'd0, max_row00} + {6'd0, max_diff00};

wire [1:0] max_row01 = (rank_row01 > rank_col01) ? rank_row01 : rank_col01;
wire [1:0] diff_row01 = u_row0 - rank_row01;
wire [1:0] diff_col01 = u_col1 - rank_col01;
wire [1:0] max_diff01 = (diff_row01 > diff_col01) ? diff_row01 : diff_col01;
assign answer01 = {6'd0, max_row01} + {6'd0, max_diff01};

wire [1:0] max_row02 = (rank_row02 > rank_col02) ? rank_row02 : rank_col02;
wire [1:0] diff_row02 = u_row0 - rank_row02;
wire [1:0] diff_col02 = u_col2 - rank_col02;
wire [1:0] max_diff02 = (diff_row02 > diff_col02) ? diff_row02 : diff_col02;
assign answer02 = {6'd0, max_row02} + {6'd0, max_diff02};

wire [1:0] max_row03 = (rank_row03 > rank_col03) ? rank_row03 : rank_col03;
wire [1:0] diff_row03 = u_row0 - rank_row03;
wire [1:0] diff_col03 = u_col3 - rank_col03;
wire [1:0] max_diff03 = (diff_row03 > diff_col03) ? diff_row03 : diff_col03;
assign answer03 = {6'd0, max_row03} + {6'd0, max_diff03};

wire [1:0] max_row10 = (rank_row10 > rank_col10) ? rank_row10 : rank_col10;
wire [1:0] diff_row10 = u_row1 - rank_row10;
wire [1:0] diff_col10 = u_col0 - rank_col10;
wire [1:0] max_diff10 = (diff_row10 > diff_col10) ? diff_row10 : diff_col10;
assign answer10 = {6'd0, max_row10} + {6'd0, max_diff10};

wire [1:0] max_row11 = (rank_row11 > rank_col11) ? rank_row11 : rank_col11;
wire [1:0] diff_row11 = u_row1 - rank_row11;
wire [1:0] diff_col11 = u_col1 - rank_col11;
wire [1:0] max_diff11 = (diff_row11 > diff_col11) ? diff_row11 : diff_col11;
assign answer11 = {6'd0, max_row11} + {6'd0, max_diff11};

wire [1:0] max_row12 = (rank_row12 > rank_col12) ? rank_row12 : rank_col12;
wire [1:0] diff_row12 = u_row1 - rank_row12;
wire [1:0] diff_col12 = u_col2 - rank_col12;
wire [1:0] max_diff12 = (diff_row12 > diff_col12) ? diff_row12 : diff_col12;
assign answer12 = {6'd0, max_row12} + {6'd0, max_diff12};

wire [1:0] max_row13 = (rank_row13 > rank_col13) ? rank_row13 : rank_col13;
wire [1:0] diff_row13 = u_row1 - rank_row13;
wire [1:0] diff_col13 = u_col3 - rank_col13;
wire [1:0] max_diff13 = (diff_row13 > diff_col13) ? diff_row13 : diff_col13;
assign answer13 = {6'd0, max_row13} + {6'd0, max_diff13};

wire [1:0] max_row20 = (rank_row20 > rank_col20) ? rank_row20 : rank_col20;
wire [1:0] diff_row20 = u_row2 - rank_row20;
wire [1:0] diff_col20 = u_col0 - rank_col20;
wire [1:0] max_diff20 = (diff_row20 > diff_col20) ? diff_row20 : diff_col20;
assign answer20 = {6'd0, max_row20} + {6'd0, max_diff20};

wire [1:0] max_row21 = (rank_row21 > rank_col21) ? rank_row21 : rank_col21;
wire [1:0] diff_row21 = u_row2 - rank_row21;
wire [1:0] diff_col21 = u_col1 - rank_col21;
wire [1:0] max_diff21 = (diff_row21 > diff_col21) ? diff_row21 : diff_col21;
assign answer21 = {6'd0, max_row21} + {6'd0, max_diff21};

wire [1:0] max_row22 = (rank_row22 > rank_col22) ? rank_row22 : rank_col22;
wire [1:0] diff_row22 = u_row2 - rank_row22;
wire [1:0] diff_col22 = u_col2 - rank_col22;
wire [1:0] max_diff22 = (diff_row22 > diff_col22) ? diff_row22 : diff_col22;
assign answer22 = {6'd0, max_row22} + {6'd0, max_diff22};

wire [1:0] max_row23 = (rank_row23 > rank_col23) ? rank_row23 : rank_col23;
wire [1:0] diff_row23 = u_row2 - rank_row23;
wire [1:0] diff_col23 = u_col3 - rank_col23;
wire [1:0] max_diff23 = (diff_row23 > diff_col23) ? diff_row23 : diff_col23;
assign answer23 = {6'd0, max_row23} + {6'd0, max_diff23};

wire [1:0] max_row30 = (rank_row30 > rank_col30) ? rank_row30 : rank_col30;
wire [1:0] diff_row30 = u_row3 - rank_row30;
wire [1:0] diff_col30 = u_col0 - rank_col30;
wire [1:0] max_diff30 = (diff_row30 > diff_col30) ? diff_row30 : diff_col30;
assign answer30 = {6'd0, max_row30} + {6'd0, max_diff30};

wire [1:0] max_row31 = (rank_row31 > rank_col31) ? rank_row31 : rank_col31;
wire [1:0] diff_row31 = u_row3 - rank_row31;
wire [1:0] diff_col31 = u_col1 - rank_col31;
wire [1:0] max_diff31 = (diff_row31 > diff_col31) ? diff_row31 : diff_col31;
assign answer31 = {6'd0, max_row31} + {6'd0, max_diff31};

wire [1:0] max_row32 = (rank_row32 > rank_col32) ? rank_row32 : rank_col32;
wire [1:0] diff_row32 = u_row3 - rank_row32;
wire [1:0] diff_col32 = u_col2 - rank_col32;
wire [1:0] max_diff32 = (diff_row32 > diff_col32) ? diff_row32 : diff_col32;
assign answer32 = {6'd0, max_row32} + {6'd0, max_diff32};

wire [1:0] max_row33 = (rank_row33 > rank_col33) ? rank_row33 : rank_col33;
wire [1:0] diff_row33 = u_row3 - rank_row33;
wire [1:0] diff_col33 = u_col3 - rank_col33;
wire [1:0] max_diff33 = (diff_row33 > diff_col33) ? diff_row33 : diff_col33;
assign answer33 = {6'd0, max_row33} + {6'd0, max_diff33};

endmodule