<!--
  artifact: readme-mermaid
  path: $GHT/.github/templates/artifacts/readme-mermaid.md
  command: $CURCMDS/git/readme-mermaid.md  (/git/readme-mermaid)
  form: HTML compare table (icon col 40x40) + fenced mermaid flowchart LR
  fill: replace every {{PLACEHOLDER}}; keep HTML <img width="40" height="40"> (DR-012)
  exemplar: gitty README.md (table → mermaid)
-->

<table>
<thead>
<tr>
<th align="left"></th>
<th align="left">{{COL_PATH}}</th>
<th align="left">{{COL_GET}}</th>
<th align="left">{{COL_VERDICT}}</th>
</tr>
</thead>
<tbody>
<tr>
<td align="left">
<img
src="{{ROW1_ICON_URL}}"
width="40"
height="40"
alt="{{ROW1_ICON_ALT}}"
/>
</td>
<td align="left">
<ul><li><code>{{ROW1_PATH}}</code></li></ul>
</td>
<td align="left">
<ul>
<li>{{ROW1_GET_1}}</li>
<li>{{ROW1_GET_2}}</li>
<li>{{ROW1_GET_3}}</li>
</ul>
</td>
<td align="left">❌<br/><br/>{{ROW1_VERDICT}}</td>
</tr>
<tr>
<td align="left">
<img
src="{{ROW2_ICON_URL}}"
width="40"
height="40"
alt="{{ROW2_ICON_ALT}}"
/>
</td>
<td align="left">
<ul><li><code>{{ROW2_PATH}}</code></li></ul>
</td>
<td align="left">
<ul>
<li>{{ROW2_GET_1}}</li>
<li>{{ROW2_GET_2}}</li>
<li>{{ROW2_GET_3}}</li>
</ul>
</td>
<td align="left">❌<br/><br/>{{ROW2_VERDICT}}</td>
</tr>
<tr>
<td align="left">
<img
src="{{ROW3_ICON_URL}}"
width="40"
height="40"
alt="{{ROW3_ICON_ALT}}"
/>
</td>
<td align="left">
<ul><li><code>{{ROW3_PATH}}</code></li></ul>
</td>
<td align="left">
<ul>
<li>{{ROW3_GET_1}}</li>
<li>{{ROW3_GET_2}}</li>
<li>{{ROW3_GET_3}}</li>
</ul>
</td>
<td align="left">✅<br/><br/>{{ROW3_VERDICT}}</td>
</tr>
</tbody>
</table>

```mermaid
flowchart LR
  T[{{START}}] --> Q{{{DECISION_1}}}
  Q -->|{{YES_LABEL}}| P[{{YES_ACTION}}]
  Q -->|{{NO_LABEL}}| H[{{NO_ACTION}}]
  P --> R[{{MERGE}}]
  H --> R
  R --> F{{{DECISION_2}}}
  F -->|{{PARTIAL_LABEL}}| D[{{PARTIAL_OUTCOME}}]
  F -->|{{FAIL_LABEL}}| K[{{FAIL_OUTCOME}}]
```
