module function_decomposer (
input [2:0] n, input [2:0] f_1, f_2, f_3, f_4, f_5, f_6, f_7, f_8, 
output valid, output [2:0] m, output [2:0] g_1, g_2, g_3, g_4, g_5, g_6, g_7, g_8, output [2:0] h_1, h_2, h_3, h_4, h_5, h_6, h_7, h_8);

function automatic [2:0] get_f_val;
input [2:0] x;
case (x)
3'b001: return f_1;
3'b010: return f_2;
3'b011: return f_3;
3'b100: return f_4;
3'b101: return f_5;
3'b110: return f_6;
3'b111: return f_7;
default: return 3'b000;
endcase
endfunction

reg valid_idempotent = 1'b1;

// Idempotency check based on n
case (n)
3'b001: if (get_f_val(f_1) != f_1) valid_idempotent = 1'b0;
3'b010: begin if (get_f_val(f_1) != f_1) valid_idempotent = 1'b0; if (get_f_val(f_2) != f_2) valid_idempotent = 1'b0; end
3'b011: begin if (get_f_val(f_1) != f_1) valid_idempotent = 1'b0; if (get_f_val(f_2) != f_2) valid_idempotent = 1'b0; if (get_f_val(f_3) != f_3) valid_idempotent = 1'b0; end
3'b100: begin if (get_f_val(f_1) != f_1) valid_idempotent = 1'b0; if (get_f_val(f_2) != f_2) valid_idempotent = 1'b0; if (get_f_val(f_3) != f_3) valid_idempotent = 1'b0; if (get_f_val(f_4) != f_4) valid_idempotent = 1'b0; end
3'b101: begin if (get_f_val(f_1) != f_1) valid_idempotent = 1'b0; if (get_f_val(f_2) != f_2) valid_idempotent = 1'b0; if (get_f_val(f_3) != f_3) valid_idempotent = 1'b0; if (get_f_val(f_4) != f_4) valid_idempotent = 1'b0; if (get_f_val(f_5) != f_5) valid_idempotent = 1'b0; end
3'b110: begin if (get_f_val(f_1) != f_1) valid_idempotent = 1'b0; if (get_f_val(f_2) != f_2) valid_idempotent = 1'b0; if (get_f_val(f_3) != f_3) valid_idempotent = 1'b0; if (get_f_val(f_4) != f_4) valid_idempotent = 1'b0; if (get_f_val(f_5) != f_5) valid_idempotent = 1'b0; if (get_f_val(f_6) != f_6) valid_idempotent = 1'b0; end
3'b111: begin if (get_f_val(f_1) != f_1) valid_idempotent = 1'b0; if (get_f_val(f_2) != f_2) valid_idempotent = 1'b0; if (get_f_val(f_3) != f_3) valid_idempotent = 1'b0; if (get_f_val(f_4) != f_4) valid_idempotent = 1'b0; if (get_f_val(f_5) != f_5) valid_idempotent = 1'b0; if (get_f_val(f_6) != f_6) valid_idempotent = 1'b0; if (get_f_val(f_7) != f_7) valid_idempotent = 1'b0; end
endcase

valid = valid_idempotent;

if (!valid_idempotent) begin
m = 3'b000;
g_1 = g_2 = g_3 = g_4 = g_5 = g_6 = g_7 = g_8 = 3'b000;
h_1 = h_2 = h_3 = h_4 = h_5 = h_6 = h_7 = h_8 = 3'b000;
end else begin
m = 3'b001;
h_1 = f_1;
g_1 = g_2 = g_3 = g_4 = g_5 = g_6 = g_7 = g_8 = 3'b001;
h_2 = h_3 = h_4 = h_5 = h_6 = h_7 = h_8 = 3'b000;
end
endmodule